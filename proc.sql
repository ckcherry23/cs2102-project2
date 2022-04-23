-- Q1.1 
-- trigger function
CREATE OR REPLACE FUNCTION check_sells_func() 
RETURNS TRIGGER AS 
$$ 
DECLARE count_products NUMERIC;

BEGIN
    SELECT
        COUNT(*) INTO count_products
    FROM
        sells
    WHERE
        NEW.id = sells.shop_id and sells.quantity > 0;

    IF (count_products < 1) THEN 
        RAISE EXCEPTION 'Each shop must sell at least one product';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
CREATE CONSTRAINT TRIGGER check_sells_trigger
AFTER INSERT ON shop 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_sells_func();

-- Q1.2 
-- trigger function
CREATE OR REPLACE FUNCTION check_order_func() 
RETURNS TRIGGER AS
$$ 
DECLARE 
    count_products INTEGER;
BEGIN
    SELECT COUNT(DISTINCT product_id) 
    INTO count_products
    FROM orderline O
    WHERE NEW.id=O.order_id and O.quantity>0;

    IF (count_products < 1) THEN
        RAISE EXCEPTION 'Order must involve one or more products from one or more shops';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
CREATE CONSTRAINT TRIGGER check_order_trigger 
AFTER INSERT ON orders  
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_order_func();

-- Q1.3 
-- trigger function
CREATE OR REPLACE FUNCTION check_order_amount_func() RETURNS TRIGGER AS $$
   DECLARE
       min_amount NUMERIC;
   BEGIN
        IF (NEW.coupon_id IS NULL) THEN
            RETURN NEW;
        END IF;

       SELECT min_order_amount
       INTO min_amount
       FROM coupon_batch C
       WHERE C.id=NEW.coupon_id;
 
       IF (NEW.payment_amount<min_amount) THEN
            RAISE NOTICE 'Coupon can be applied to only to an order whose amount exceeds minimum amount';
            RETURN NULL;
       END IF;
       RETURN NEW;
   END;
$$ LANGUAGE plpgsql;

-- trigger 
CREATE TRIGGER check_order_amount_trigger
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION check_order_amount_func();

-- 1.4 
--trigger function:
CREATE OR REPLACE FUNCTION check_refund_qty_func() RETURNS TRIGGER AS $$
   DECLARE
       already_requested_qty INTEGER;
       ordered_qty INTEGER;
 
   BEGIN
       SELECT SUM(quantity)
       INTO already_requested_qty
       FROM refund_request R
       WHERE R.status <> 'rejected' 
            and R.order_id=NEW.order_id 
            and R.shop_id=NEW.shop_id 
            and R.product_id=NEW.product_id 
            and R.sell_timestamp=NEW.sell_timestamp; 
 
       SELECT quantity
       INTO ordered_qty
       FROM orderline O
       WHERE O.order_id=NEW.order_id 
            and O.shop_id=NEW.shop_id 
            and O.product_id=NEW.product_id 
            and O.sell_timestamp=NEW.sell_timestamp;
    
        IF (already_requested_qty IS NULL) THEN
            already_requested_qty := 0;
        END IF;
 
       IF (NEW.quantity + already_requested_qty > ordered_qty) THEN
           RAISE NOTICE 'Refund quantity has exceeded the ordered quantity';
           RETURN NULL;
       END IF;
       
       RETURN NEW;
   END;
$$ LANGUAGE plpgsql;

-- trigger
CREATE TRIGGER check_refund_qty_trigger
BEFORE INSERT ON refund_request
FOR EACH ROW
EXECUTE FUNCTION check_refund_qty_func();

-- Q1.5 
--trigger function:
CREATE OR REPLACE FUNCTION check_request_date_func() RETURNS TRIGGER AS $$
   DECLARE
       product_delivery_date DATE;
   BEGIN
       SELECT O.delivery_date
       INTO product_delivery_date
       FROM orderline O
       WHERE O.order_id=NEW.order_id and O.shop_id= NEW.shop_id and O.product_id=NEW.shop_id and O.sell_timestamp=NEW.sell_timestamp;
 
       IF (NEW.request_date - product_delivery_date > 30) THEN
           RAISE NOTICE 'Refund request date must be within 30 days of the delivery date';
           RETURN NULL;
       END IF;
       RETURN NEW;
   END;
$$ LANGUAGE plpgsql;

-- trigger:
CREATE TRIGGER check_request_date_trigger
BEFORE INSERT ON refund_request
FOR EACH ROW
EXECUTE FUNCTION check_request_date_func();
 
-- Q1.6 
-- trigger function
CREATE OR REPLACE FUNCTION check_product_delivered_func() RETURNS TRIGGER AS $$
   DECLARE
       delivery_status orderline_status;
   BEGIN
       SELECT status
       INTO delivery_status
       FROM orderline O
       WHERE O.order_id=NEW.order_id and O.shop_id=NEW.shop_id and O.product_id=NEW.product_id and O.sell_timestamp=NEW.sell_timestamp;
 
       IF (delivery_status<>'delivered') THEN
           RAISE NOTICE 'Refund request can only be made for a delivered product';
           RETURN NULL;
       END IF;
       RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

-- trigger
CREATE TRIGGER check_product_delivered_trigger
BEFORE INSERT ON refund_request
FOR EACH ROW
EXECUTE FUNCTION check_product_delivered_func();

-- Q1.7
-- trigger function
CREATE OR REPLACE FUNCTION check_review_user_func() 
RETURNS TRIGGER AS
$$ 
DECLARE review_user INTEGER;
        order_user INTEGER;

BEGIN
    review_user := (SELECT
        user_id
    FROM
        comment
    WHERE
        NEW.id = comment.id);

    order_user = (SELECT
        user_id
    FROM
        orders
    WHERE
        NEW.order_id = orders.id);

    IF (review_user <> order_user) THEN 
        RAISE NOTICE 'Reviews should be given by the same user who ordered the product';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
DROP TRIGGER IF EXISTS check_review_user_trigger on review;

CREATE TRIGGER check_review_user_trigger 
BEFORE INSERT ON review  
FOR EACH ROW EXECUTE FUNCTION check_review_user_func();


-- Q1.8
-- trigger function 
CREATE OR REPLACE FUNCTION check_review_or_reply_func()
RETURNS TRIGGER AS $$
    DECLARE review_count INTEGER;
            reply_count INTEGER;

    BEGIN
        review_count := (SELECT
            count(*)
        FROM
            review
        WHERE
            NEW.id = review.id);

        reply_count = (SELECT
            count(*)
        FROM
            reply
        WHERE
            NEW.id = reply.id);

        IF (review_count + reply_count <> 1) THEN 
            RAISE EXCEPTION 'All comments should only be either a review or a reply';
            RETURN NULL;
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

-- trigger
DROP TRIGGER IF EXISTS check_review_or_reply_trigger on comment;

CREATE CONSTRAINT TRIGGER check_review_or_reply_trigger 
AFTER INSERT ON comment 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_review_or_reply_func();


-- Q1.9
-- trigger function
CREATE OR REPLACE FUNCTION check_reply_version_func() 
RETURNS TRIGGER AS
$$ 
DECLARE reply_count INTEGER;

BEGIN
    reply_count = (SELECT
        count(*)
    FROM
        reply_version
    WHERE
        NEW.id = reply_version.reply_id);

    IF (reply_count < 1) THEN 
        RAISE EXCEPTION 'Replies must have at least one version';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
DROP TRIGGER IF EXISTS check_reply_version_trigger on reply;

CREATE CONSTRAINT TRIGGER check_reply_version_trigger 
AFTER INSERT ON reply
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_reply_version_func();


-- Q1.10
-- trigger function
CREATE OR REPLACE FUNCTION check_review_version_func() 
RETURNS TRIGGER AS
$$ 
DECLARE review_count INTEGER;

BEGIN
    review_count = (SELECT
        count(*)
    FROM
        review_version
    WHERE
        NEW.id = review_version.review_id);

    IF (review_count < 1) THEN 
        RAISE EXCEPTION 'Reviews must have at least one version';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
DROP TRIGGER IF EXISTS check_review_version_trigger on review;

CREATE CONSTRAINT TRIGGER check_review_version_trigger 
AFTER INSERT ON review 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_review_version_func();


-- Q1.11
-- trigger function
CREATE OR REPLACE FUNCTION check_complaint_status_func() 
RETURNS TRIGGER AS
$$ 
DECLARE item_status orderline_status;
BEGIN
    item_status := (SELECT
        status
    FROM
        orderline
    WHERE
        NEW.order_id = orderline.order_id
        AND NEW.product_id = orderline.product_id
        AND NEW.shop_id = orderline.shop_id
        AND NEW.sell_timestamp = orderline.sell_timestamp);

    IF (item_status <> 'delivered'::orderline_status) THEN 
        RAISE NOTICE 'Delivery complaint can only be registered on delivered products';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
DROP TRIGGER IF EXISTS check_complaint_status_trigger ON delivery_complaint;

CREATE TRIGGER check_complaint_status_trigger 
BEFORE INSERT ON delivery_complaint
FOR EACH ROW EXECUTE FUNCTION check_complaint_status_func();


-- Q1.12
-- trigger function
CREATE OR REPLACE FUNCTION check_complaint_isa_func() 
RETURNS TRIGGER AS
$$ 
DECLARE delivery_count INTEGER;
        shop_count INTEGER;
        comment_count INTEGER;

BEGIN
    delivery_count := (SELECT
        count(*)
    FROM
        delivery_complaint
    WHERE
        NEW.id = delivery_complaint.id);

    shop_count := (SELECT
        count(*)
    FROM
        shop_complaint
    WHERE
        NEW.id = shop_complaint.id);

    comment_count := (SELECT
        count(*)
    FROM
        comment_complaint
    WHERE
        NEW.id = comment_complaint.id);

    IF (delivery_count + shop_count + comment_count <> 1) THEN 
        RAISE EXCEPTION 'All complaints should only be against either a delivery, a shop or a comment';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- trigger
DROP TRIGGER IF EXISTS check_complaint_isa_trigger ON complaint;

CREATE CONSTRAINT TRIGGER check_complaint_isa_trigger 
AFTER INSERT ON complaint
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_complaint_isa_func();

-- Q2.1.1
CREATE OR REPLACE PROCEDURE place_order(
    user_id INTEGER, 
    coupon_id INTEGER, 
    shipping_address TEXT, 
    shop_ids INTEGER[], 
    product_ids INTEGER[], 
    sell_timestamps TIMESTAMP[], 
    quantities INTEGER[], 
    shipping_costs NUMERIC[])
AS $$
    DECLARE
        coupon_reward NUMERIC := 0.0;
        min_payment_amount NUMERIC := 0.0;
        product_price NUMERIC := 0.0;
        total_price NUMERIC := 0.0;
        product_quantity INTEGER := 0;
        order_quantity INTEGER := 0;
        i INTEGER := 1;
        index_limit INTEGER := 0;
        order_id INTEGER := 0;
    BEGIN

        FOREACH order_quantity IN ARRAY quantities LOOP
            -- Each orderline will have one entry in each array.
            SELECT price, quantity INTO product_price, product_quantity 
            FROM sells 
            where (shop_id, product_id, sell_timestamp) = (shop_ids[i], product_ids[i], sell_timestamps[i]);

            -- Payment = price * quantity + shipping_cost
            total_price := total_price + (product_price * order_quantity + shipping_costs[i]);
            
            -- Check if we are purchasing more than the available number of products.
            IF product_quantity >= order_quantity THEN 
                -- Quantity sold for each product listing involved should be updated after order is placed successfully.
                UPDATE sells 
                SET quantity = product_quantity - order_quantity
                WHERE (shop_id, product_id, sell_timestamp) = (shop_ids[i], product_ids[i], sell_timestamps[i]);
            ELSE 
                RAISE EXCEPTION 'Cannot purchase more than the available amount of products.';
                RETURN;
            END IF;

            i := i + 1;
        END LOOP;
        
        -- The coupon_id is optional; it is NULL if the user does not use a coupon.
        IF coupon_id IS NOT NULL THEN 
            SELECT reward_amount, min_order_amount INTO coupon_reward, min_payment_amount
            FROM coupon_batch
            WHERE id = coupon_id;
        END IF;

        -- Raise exception when total_price < min_payment_amount
        IF coupon_id IS NOT NULL and total_price < min_payment_amount THEN
            -- Ensure rollback when exception is raised.
            RAISE EXCEPTION 'Price of order is smaller than minimum order amount of coupon used.';
            RETURN;
        END IF;

        -- Places order by user for selected product listings. 
        INSERT into orders(user_id, coupon_id, shipping_address, payment_amount) VALUES(
            user_id,
            coupon_id,
            shipping_address,
            total_price - coupon_reward
        );

        SELECT id INTO order_id
        FROM orders
        ORDER BY id DESC
        LIMIT 1;

        -- Prepare to re-traverse the array.
        index_limit := i;
        i := 1;

        -- Insert all product orderline for this order.
        WHILE i < index_limit LOOP    
            INSERT INTO orderline VALUES(
                order_id,
                shop_ids[i],
                product_ids[i],
                sell_timestamps[i],
                quantities[i],
                shipping_costs[i],
                'being_processed',
                NULL
            );

            i := i + 1;
        END LOOP;    
    
    END;
$$ LANGUAGE plpgsql;

-- Q2.1.2
CREATE OR REPLACE PROCEDURE review(
    user_id INTEGER, 
    order_id INTEGER, 
    shop_id INTEGER, 
    product_id INTEGER, 
    sell_timestamp TIMESTAMP, 
    content TEXT, 
    rating INTEGER, 
    comment_timestamp TIMESTAMP) 
AS $$
    DECLARE
        review_id INTEGER := NULL;
    BEGIN

        IF rating NOT IN (1,2,3,4,5) THEN
            RAISE EXCEPTION 'Input rating is invalid.';
            RETURN;
        END IF;    
        -- Creates a review by the given user for the particular ordered product.
        INSERT INTO comment(user_id) VALUES (user_id);

        -- review_id = the id generated by the most recent insertion.
        SELECT id INTO review_id 
        FROM comment
        ORDER BY id DESC
        LIMIT 1;

        INSERT INTO review VALUES(
            review_id,
            order_id,
            shop_id,
            product_id,
            sell_timestamp
        );

        INSERT INTO review_version VALUES(
            review_id,
            comment_timestamp,
            content,
            rating
        );
    END;
$$ LANGUAGE plpgsql;

-- Q2.1.3
CREATE OR REPLACE PROCEDURE reply(
    user_id INTEGER, 
    other_comment_id INTEGER, 
    content TEXT, 
    reply_timestamp TIMESTAMP) 
AS $$
    DECLARE
        reply_id INTEGER := NULL;
    BEGIN
        -- Check if other_comment_id is inside comment.
        IF NOT EXISTS(
            SELECT 1
            FROM comment
            WHERE id = other_comment_id
        ) THEN 
            RAISE EXCEPTION 'Input other_comment_id is not valid.';
            RETURN;
        END IF;
        
        -- Creates a reply from user on another comment.
        INSERT INTO comment(user_id) VALUES (user_id);

        -- reply_id = the id generated by the most recent insertion.
        SELECT id INTO reply_id 
        FROM comment
        ORDER BY id DESC
        LIMIT 1;

        INSERT INTO reply VALUES(
            reply_id,
            other_comment_id
        );

        INSERT INTO reply_version VALUES(
            reply_id,
            reply_timestamp,
            content
        );
    END;
$$ LANGUAGE plpgsql;


-- Question 2.2.1
create or replace function view_comments(
    in shop_id INTEGER, in product_id INTEGER, 
    in sell_timestamp TIMESTAMP 
) returns table(
    username varchar, content varchar,
    rating integer, comment_timestamp TIMESTAMP)
as $$
declare
    sid integer := shop_id;
    pid integer := product_id;
    timing timestamp := sell_timestamp;
    defat integer := NULL;
    curs cursor for (
        -- select all reviews of the targeted product by the user
        with table1 as (select C.id as cid, U.id as uid, U.name as name, U.account_closed as status,
        (select Ra.review_timestamp from review_version Ra where Ra.review_id = C.id order by review_timestamp desc limit 1) as timing,
        (select Rb.content from review_version Rb where Rb.review_id = C.id order by review_timestamp desc limit 1) as content,
        (select Rc.rating from review_version Rc where Rc.review_id = C.id order by review_timestamp desc limit 1) as rating
        from comment C inner join users U on C.user_id = U.id
        where exists (select * from review R1 where R1.id = C.id and
        R1.shop_id = sid and R1.product_id = pid and R1.sell_timestamp = timing)
        ),
        -- select all replies of the target reviews
        table2 as (select C.id as cid, U.id as uid, U.name as name, U.account_closed as status,
        (select Ra.reply_timestamp from reply_version Ra where Ra.reply_id = C.id order by reply_timestamp desc limit 1) as timing,
        (select Rb.content from reply_version Rb where Rb.reply_id = C.id order by reply_timestamp desc limit 1) as content,
        defat as rating
        from comment C inner join users U on C.user_id = U.id
        inner join reply R on R.id = C.id
        where R.other_comment_id in (select cid from table1)
        )
        select * from table1 union select * from table2 order by timing, cid
    );
    r1 record;
begin

    open curs;
    loop
        fetch curs into r1;
        exit when not found;
        if r1.status = true then
            username := 'A Deleted User';
        else
            username := r1.name;
        end if;
        content := r1.content;
        rating := r1.rating;
        comment_timestamp := r1.timing;
        return next;
    end loop;
    close curs;
    
end;
$$ language plpgsql;

-- Question 2.2.2
create or replace function get_most_returned_products_from_manufacturer( 
    manufacturer_id INTEGER, n INTEGER)
returns TABLE ( 
    product_id INTEGER, product_name TEXT, return_rate NUMERIC(3, 2) 
) as $$
declare
    mid integer := manufacturer_id;
    curs cursor for (
        -- each product and their corresponding manufacturer
        with table1 as (
            select P.id, P.name, sum(quantity) as val from product P left outer join orderline O
            on P.id = O.product_id where P.manufacturer = manufacturer_id and O.status = 'delivered'
            group by P.id, P.name
        ), table2 as (
            select P.id, P.name, coalesce(sum(quantity), 0) as val from product P left outer join refund_request R
            on P.id = R.product_id where P.manufacturer = manufacturer_id and R.status = 'accepted'
            group by P.id, P.name
        ) select P.id as id, P.name as name, 
        round(coalesce((T2.val::numeric/ T1.val::numeric), 0), 2) as ratio from 
        product P left outer join
        table1 T1 on P.id = T1.id full outer join 
        table2 T2 on T1.id = T2.id and T1.name = T2.name
        where P.manufacturer = mid
        order by coalesce((T2.val::numeric/ T1.val::numeric), 0.00) desc, P.id limit n
    );
    r record;
    i integer := 0;
begin
    open curs;
    loop
        fetch curs into r;
        exit when not found;
        product_id := r.id;
        product_name := r.name;
        return_rate := r.ratio;
        return next;
    end loop;
    close curs;
end;

$$ language plpgsql;

-- Question 2.2.3
create or replace function get_worst_shops(n integer)
returns table(shop_id integer, shop_name text, num_negative_indicators integer) as
$$

declare
    curs cursor for (
        with table1 as (
            select S.id as sid, S.name as name,
            coalesce((select count(*) from (select distinct O.order_id, O.shop_id, O.product_id, O.sell_timestamp 
                from refund_request O where O.shop_id = S.id) M), 0) as criteria1,
            coalesce((select count(*) from shop_complaint B where B.shop_id = S.id), 0) as criteria2,
            coalesce((select count(*) from (select distinct C.order_id, C.shop_id, C.product_id, C.sell_timestamp 
                from delivery_complaint C where C.shop_id = S.id) N), 0) as criteria3,
            coalesce((select count(*) from review D inner join review_version E on D.id = E.review_id
                where D.shop_id = S.id and E.rating = 1 and E.review_timestamp = (
                    select max(F.review_timestamp) from review_version F where F.review_id = D.id
                )), 0) as criteria4
            from shop S
        )
        select T.sid, T.name, (T.criteria1 + T.criteria2 + T.criteria3 + T.criteria4) 
        as num from table1 T order by (T.criteria1 + T.criteria2 + T.criteria3 + T.criteria4) desc limit n
    );
    r record;
    i integer;
    count integer := 0;
begin
    open curs;
    loop
        fetch curs into r;
        exit when not found;
        shop_id = r.sid;
        shop_name = r.name;
        num_negative_indicators = r.num;
        return next;
    end loop;
    close curs;
end;

$$ language plpgsql;