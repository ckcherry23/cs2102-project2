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
        i INTEGER := 0;
    BEGIN

        -- The coupon_id is optional; it is NULL if the user does not use a coupon.
        IF coupon_id IS NOT NULL THEN 
            SELECT reward_amount, min_order_amount INTO coupon_reward, min_payment_amount
            FROM coupon_batch
            WHERE id = coupon_id;
        END IF;

        
    
        FOREACH i IN ARRAY shop_ids LOOP
            -- Each orderline will have one entry in each array.
            SELECT price INTO product_price FROM sells 
            where (shop_id, product_id, sell_timestamp) = (shop_ids[i], product_ids[i], sell_timestamps[i]);

            -- Payment = price * quantity + shipping_cost
            total_price := total_price + (product_price * quantities[i] + shipping_costs[i]);
            
            -- Quantity sold for each product listing involved should be updated after order is placed successfully.
            UPDATE sells 
            SET quantity = quantity - quantities[i]
            WHERE (shop_id, product_id, sell_timestamp) = (shop_ids[i], product_ids[i], sell_timestamps[i]);
        END LOOP;

        -- Raise exception when total_price < min_payment_amount
        IF coupon_id IS NOT NULL and total_price < min_payment_amount THEN
            -- Ensure rollback when exception is raised.
            ROLLBACK;
            RAISE EXCEPTION 'Price of order is smaller than minimum order amount of coupon used.';
            RETURN;
        END IF;

        -- Places order by user for selected product listings. 
        INSERT into orders VALUES(
            user_id,
            coupon_id,
            shipping_address,
            total_price - coupon_reward
        );
    
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
        -- Creates a review by the given user for the particular ordered product.
        INSERT INTO comment VALUES (user_id);

        -- review_id = the id generated by the most recent insertion.
        -- are we sure this will work? returning? curval?
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
            RAISE EXCEPTION 'other_comment_id is not valid.';
            RETURN;
        END IF;
        
        -- Creates a reply from user on another comment.
        INSERT INTO comment VALUES (user_id);

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
