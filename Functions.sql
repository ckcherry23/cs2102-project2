-- Q2.2.1
CREATE OR REPLACE FUNCTION view_comments(input_shop_id INTEGER, input_product_id INTEGER, input_sell_timestamp TIMESTAMP)
RETURNS TABLE(username TEXT, content TEXT, rating INTEGER, comment_timestamp TIMESTAMP) AS $$ 
    DECLARE
        curs CURSOR FOR (
            -- Retrieves info about all comments related to a product listing
            WITH review_ids AS (
                SELECT id FROM review
                WHERE (shop_id, product_id, sell_timestamp) = (input_shop_id, input_product_id, input_sell_timestamp)
            ), reply_ids AS (
                SELECT id FROM reply
                WHERE id IN (SELECT * FROM review_ids)
            ), review_time AS (
                SELECT id, review_timestamp AS stamp, content, rating
                FROM review_version V1
                WHERE id IN (SELECT * FROM review_ids)
                AND NOT EXISTS (
                    SELECT 1
                    FROM review_version V2
                    WHERE V1.id = V2.id
                    -- If a comment has multiple versions, return only the latest version 
                    AND V1.review_timestamp < V2.review_timestamp
                )
            ), reply_time AS (
                SELECT id, reply_timestamp AS stamp, content, NULL AS rating
                FROM reply_version V1
                WHERE id IN (SELECT * FROM reply_ids)
                AND NOT EXISTS (
                    SELECT 1
                    FROM reply_version V2
                    WHERE V1.id = V2.id 
                    AND V1.reply_timestamp < V2.reply_timestamp
                )
            ), all_entries AS (    
                SELECT * 
                FROM review_time
                UNION
                SELECT * 
                FROM reply_time
            )
            SELECT * 
            FROM all_entries
            -- Results should be ordered ascending by the timestamp of the latest version of each comment.
            -- In the case of a tie in comment_timestamp, order them ascending by comment_id.
            ORDER BY stamp, id ASC
        );

        r1 RECORD;
    BEGIN

    open curs;
    LOOP

    -- Iterate through the table 
    FETCH curs INTO r1;
    EXIT WHEN NOT FOUND;

    -- If a comment belongs to a deleted user, display their name as ‘A Deleted User’ rather than their original username. 
    SELECT CASE
        WHEN account_closed THEN 'A Deleted User'
        ELSE users.name 
    END INTO username
    FROM users
    WHERE users.id = (
        SELECT user_id 
        FROM comment 
        WHERE comment.id = r1.id);

    content := r1.content;
    rating := r1.rating;
    comment_timestamp := r1.stamp;

    RETURN NEXT;

    END LOOP;
    CLOSE curs;

    END;
$$ LANGUAGE plpgsql;

-- Q2.2.2
CREATE OR REPLACE FUNCTION get_most_returned_products_from_manufacturer(manufacturer_id INTEGER, n INTEGER)
RETURNS TABLE(product_id INTEGER, product_name TEXT, return_rate NUMERIC(3,2)) AS $$
    DECLARE
        curs CURSOR FOR (
            WITH sold_products AS (
                SELECT product.id, product.name, COALESCE(sum(sells.quantity),0) as quantity
                FROM product left join sells
                    ON product.id = sells.product_id
                WHERE product.manufacturer = manufacturer_id
                GROUP BY product_id
            ), refunded AS (
                SELECT product_id, COALESCE(sum(quantity), 0) AS quantity
                FROM refund_request
                WHERE product_id IN (SELECT id FROM sold_products)
                -- Products are only successfully refunded if the refund_request status is ‘accepted’ 
                and refund_status = 'accepted'
                GROUP BY product_id
            ), all_refunded AS (
                SELECT product_id, product_name, 
                CASE 
                    -- If a product has never been ordered, its return_rate should default to 0.00 
                    WHEN sold_products.quantity = 0 THEN 0
                    -- Return rate for a product is calculated as (sum of quantity successfully returned across all orders) 
                    -- / (sum of quantity delivered across all orders) 
                    -- The return rate should be a numeric value between 0.00 and 1.00, rounded off to the nearest 2 decimal places. 
                    ELSE round(refunded.quantity / sold_products.quantity * 100) / 100
                END AS return_rate
                FROM sold_products LEFT JOIN refunded 
                ON sold_products.id = refunded.product_id
            )
            SELECT * 
            FROM all_refunded
            -- Results should be ordered descending by return_rate 
            -- In the case of a tie in return_rate, order them ascending by product_id 
            ORDER BY  return_rate DESC, product_id ASC
            -- Obtains the N products from the provided manufacturer that have the highest return rate.
            LIMIT n
        );

        rec RECORD;
    BEGIN

    open curs;

    LOOP
        -- Obtains the first n products.
        FETCH curs INTO rec;
        EXIT WHEN NOT FOUND;

        product_id := rec.product_id;
        product_name := rec.product_name;
        return_rate := rec.return_rate;
        RETURN NEXT;


    END LOOP;
    close curs;

    END;
$$ LANGUAGE plpgsql;

-- Q2.2.3
CREATE OR REPLACE FUNCTION get_worst_shops(n INTEGER)
RETURNS TABLE(shop_id INTEGER, shop_name TEXT, num_negative_indicators INTEGER) AS $$
    DECLARE
        curs CURSOR FOR (
            WITH num_refund AS (
                -- Each ordered product from that shop which has a refund request 
                -- (regardless of status) is considered as one negative indicator. 
                SELECT shop.id AS sid, count(shop_id) AS num
                FROM shop LEFT JOIN refund_request 
                    ON shop.id = refund_request.shop_id
                GROUP BY shop.id    
            ), num_complaint AS (
                -- Each shop complaint (regardless of status) is considered as one negative indicator. 
                SELECT shop.id AS sid, count(shop_id) AS num
                FROM shop LEFT JOIN shop_complaint
                    ON shop.id = shop_complaint.shop_id
                GROUP BY shop.id    
            ), num_delivery_complaint AS (
                -- Each delivery complaint (regardless of status) for a delivered product by that shop
                -- is considered as one negative indicator. 
                SELECT shop.id AS sid, count(shop_id) AS num
                FROM shop LEFT JOIN delivery_complaint
                    ON shop.id = delivery_complaint.shop_id
                GROUP BY shop.id
            ), num_reviews AS (
                SELECT shop.id AS sid, count(bad_reviews.sid) AS negative_count
                FROM shop LEFT JOIN (
                    SELECT R1.shop_id AS sid, R1.id AS rid
                    FROM review R1 INNER JOIN review_version R2
                        ON R1.id = R2.review_id
                    WHERE NOT EXISTS (
                        SELECT 1 
                        FROM review_version R3
                        WHERE R2.id = R3.id
                        -- Only consider the latest version of the review.
                        and R2.review_timestamp < R3.review_timestamp
                    ) and R2.rating = 1
                ) AS bad_reviews 
                    ON shop.id = bad_reviews.sid
                GROUP BY shop.id    
            ), total_sum AS (
                SELECT * 
                FROM num_refund
                UNION ALL
                SELECT * 
                FROM num_complaint
                UNION ALL
                SELECT * 
                FROM num_delivery_complaint
                UNION ALL
                SELECT * 
                FROM num_reviews
            )
            SELECT sid, COALESCE(sum(num), 0) AS negative_count
            FROM total_sum
            -- Results should be ordered descending by num_negative_indicators.
            -- In the case of a tie in num_negative_indicators, order them ascending by shop_id.
            GROUP BY sid
            ORDER BY negative_count DESC, sid ASC
            -- Finds the N worst shops, judging by the number of negative indicators that they have.
            LIMIT n
        );

        rec RECORD;
    BEGIN
        OPEN curs;
        LOOP
            FETCH curs INTO rec;
            EXIT WHEN NOT FOUND;
            
            shop_id := rec.sid;
            shop_name := rec.name;
            num_negative_indicators := rec.negative_count;
            RETURN NEXT;
        END LOOP;
        CLOSE curs;
    END;
$$ LANGUAGE plpgsql;
