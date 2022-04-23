--(1)
CREATE CONSTRAINT TRIGGER check_sells_trigger
AFTER INSERT ON shop
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_sells_func();
 
CREATE OR REPLACE FUNCTION check_sells_func()
RETURNS TRIGGER AS
$$
DECLARE count NUMERIC;
 
BEGIN
   SELECT
       COUNT(*) INTO count
   FROM
       sells
   WHERE
       NEW.id = sells.shop_id and sells.quantity > 0;
 
   IF (count < 1) THEN
       RAISE NOTICE 'Each shop must sell at least one product.';
       RETURN NULL;
   END IF;
 
   RETURN NEW;
END;
 
$$ LANGUAGE plpgsql;

---------------------------------------------------------------------------------------
--(2)
CREATE TRIGGER check_order_trigger 
BEFORE INSERT ON orders  
FOR EACH ROW EXECUTE FUNCTION check_order_func();

CREATE OR REPLACE FUNCTION check_order_func() 
RETURNS TRIGGER AS
$$ 
DECLARE count_shops NUMERIC;
        count_products NUMERIC;
BEGIN
    -- SELECT
    --     COUNT(DISTINCT shop_id) INTO count_shops
    -- FROM
    --     orderline
    -- WHERE
    --     NEW.order_id = orderline.order_id;

    -- SELECT
    --     COUNT(DISTINCT product_id) INTO count_shops
    -- FROM
    --     orderline
    -- WHERE
    --     NEW.order_id = orderline.order_id;

    -- IF (count_products < 1) THEN 
    --     RAISE EXCEPTION 'Each order must have at least 1 product';
    --     RETURN NULL;
    -- END IF;

    -- IF (count_shops < 1) THEN 
    --     RAISE EXCEPTION 'Each order must have products from at least 1 shop';
    --     RETURN NULL;
    -- END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;


---------------------------------------------------------------------------------------
--(3)
CREATE TRIGGER check_coupon_trigger 
BEFORE INSERT ON orders  --??? Transaction
FOR EACH ROW EXECUTE FUNCTION check_coupon_func();

CREATE OR REPLACE FUNCTION check_coupon_func() 
RETURNS TRIGGER AS
$$ 
DECLARE min_amount NUMERIC;
BEGIN
    -- min_amount := (SELECT
    --     min_order_amount
    -- FROM
    --     coupon_batch
    -- WHERE
    --     NEW.coupon_id = coupon_batch.id);

    -- IF (NEW.payment_amount < min_amount) THEN  -- (<=)?
    --     RAISE EXCEPTION 'This coupon cannot be applied to this order';
    --     RETURN NULL;
    -- END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;


---------------------------------------------------------------------------------------
--(4)
CREATE TRIGGER check_refund_qty_trigger 
BEFORE INSERT ON refund_request  --??? Transaction
FOR EACH ROW EXECUTE FUNCTION check_refund_qty_func();

CREATE OR REPLACE FUNCTION check_refund_qty_func() 
RETURNS TRIGGER AS
$$ 
DECLARE ordered_qty NUMERIC;
        refund_qty_sum NUMERIC;
BEGIN
    -- ordered_qty := (SELECT
    --     quantity
    -- FROM
    --     orderline
    -- WHERE
    --     NEW.order_id = orderline.order_id
    --     AND NEW.product_id = orderline.product_id
    --     AND NEW.shop_id = orderline.shop_id
    --     AND NEW.sell_timestamp = orderline.sell_timestamp);

    -- refund_qty_sum := (SELECT
    --     sum(quantity)
    -- FROM
    --    refund_request
    -- WHERE
    --     NEW.order_id = refund_request.order_id
    --     AND NEW.product_id = refund_request.product_id
    --     AND NEW.shop_id = refund_request.shop_id
    --     AND NEW.sell_timestamp = refund_request.sell_timestamp
    --     AND refund_request.status <> "rejected");

    -- IF (refund_qty_sum > ordered_qty) THEN
    --     RAISE EXCEPTION 'Refund quantity cannot be greater than ordered quantity';
    --     RETURN NULL;
    -- END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;


---------------------------------------------------------------------------------------
--(5)
CREATE TRIGGER check_refund_date_trigger 
BEFORE INSERT ON refund_request  --??? Transaction
FOR EACH ROW EXECUTE FUNCTION check_refund_date_func();

CREATE OR REPLACE FUNCTION check_refund_date_func() 
RETURNS TRIGGER AS
$$ 
DECLARE deliv_date DATE;
        date_diff INT;
BEGIN
    -- deliv_date := (SELECT
    --     delivery_date
    -- FROM
    --     orderline
    -- WHERE
    --     NEW.order_id = orderline.order_id
    --     AND NEW.product_id = orderline.product_id
    --     AND NEW.shop_id = orderline.shop_id
    --     AND NEW.sell_timestamp = orderline.sell_timestamp);

    -- date_diff := NEW.request_date::DATE - deliv_date::DATE;

    -- IF (date_diff > 30) THEN --(>=)?
    --     RAISE EXCEPTION 'Refund must be requested within 30 days of delivery';
    --     RETURN NULL;
    -- END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;


---------------------------------------------------------------------------------------
--(6)
CREATE TRIGGER check_refund_status_trigger 
BEFORE INSERT ON refund_request  --??? Transaction
FOR EACH ROW EXECUTE FUNCTION check_refund_status_func();

CREATE OR REPLACE FUNCTION check_refund_status_func() 
RETURNS TRIGGER AS
$$ 
DECLARE item_status orderline_status;
BEGIN
    -- item_status := (SELECT
    --     status
    -- FROM
    --     orderline
    -- WHERE
    --     NEW.order_id = orderline.order_id
    --     AND NEW.product_id = orderline.product_id
    --     AND NEW.shop_id = orderline.shop_id
    --     AND NEW.sell_timestamp = orderline.sell_timestamp);

    -- IF (item_status <> "delivered"::orderline_status) THEN 
    --     RAISE EXCEPTION 'Refund can only be requested on delviered products';
    --     RETURN NULL;
    -- END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;


---------------------------------------------------------------------------------------
--(7)
CREATE TRIGGER check_review_user_trigger 
BEFORE INSERT ON review  
FOR EACH ROW EXECUTE FUNCTION check_review_user_func();

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

---------------------------------------------------------------------------------------
--(8)
DROP TRIGGER check_review_or_reply_trigger on comment;

CREATE CONSTRAINT TRIGGER check_review_or_reply_trigger 
AFTER INSERT ON comment 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_review_or_reply_func();
 
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

---------------------------------------------------------------------------------------
--(9)
DROP TRIGGER check_reply_version_trigger on reply;

CREATE CONSTRAINT TRIGGER check_reply_version_trigger 
AFTER INSERT ON reply
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_reply_version_func();

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


---------------------------------------------------------------------------------------
--(10)
DROP TRIGGER check_review_version_trigger on review;

CREATE CONSTRAINT TRIGGER check_review_version_trigger 
AFTER INSERT ON review 
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_review_version_func();

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


---------------------------------------------------------------------------------------
--(11)
CREATE TRIGGER check_complaint_status_trigger 
BEFORE INSERT ON delivery_complaint
FOR EACH ROW EXECUTE FUNCTION check_complaint_status_func();

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


---------------------------------------------------------------------------------------
--(12)
DROP TRIGGER check_complaint_isa_trigger ON complaint;
DROP TRIGGER check_complaint_isa_trigger ON comment;

CREATE CONSTRAINT TRIGGER check_complaint_isa_trigger 
AFTER INSERT ON complaint
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_complaint_isa_func();

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
