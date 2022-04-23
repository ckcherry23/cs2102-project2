TRUNCATE users CASCADE;
TRUNCATE shop CASCADE;
TRUNCATE category CASCADE;
TRUNCATE manufacturer CASCADE;
TRUNCATE coupon_batch CASCADE;
TRUNCATE employee CASCADE;

INSERT INTO users (id, address, name, account_closed) VALUES
(1, '23 street', 'Alice', false),
(2, '23 street', 'Bob', false)
;

INSERT INTO employee (id, name, salary) VALUES
(1, 'Luke', 10000)
;

INSERT INTO shop (id, name) VALUES
(1, 'FairPrice')
;

INSERT INTO category (id, name, parent) VALUES
(1, 'Dairy', NULL)
;

INSERT INTO manufacturer (id, name, country) VALUES
(1, 'Meiji', 'Malaysia')
;

INSERT INTO product (id, name, description, category, manufacturer) VALUES
(1, 'Milk', 'low fat', 1, 1)
;

INSERT INTO sells (shop_id, product_id, sell_timestamp, price, quantity) VALUES
(1, 1, CURRENT_DATE, 10, 10)
;

INSERT INTO orders (id, user_id, coupon_id, shipping_address, payment_amount) VALUES
(1, 1, NULL, 'UTown', 13),
(2, 2, NULL, 'UTown', 13),
(3, 2, NULL, 'UTown', 13)
;

INSERT INTO orderline (order_id, shop_id, product_id, sell_timestamp, quantity, shipping_cost, status, delivery_date) VALUES
(1, 1, 1, CURRENT_DATE, 2, 3, 'delivered'::orderline_status, CURRENT_DATE),
(2, 1, 1, CURRENT_DATE, 2, 3, 'delivered'::orderline_status, CURRENT_DATE),
(3, 1, 1, CURRENT_DATE, 2, 3, 'being_processed'::orderline_status, NULL)
;

BEGIN;

INSERT INTO comment (id, user_id) VALUES
(1, 1),
(2, 2),
(3, 2),
(4, 2)
;

INSERT INTO review (id, order_id, shop_id, product_id, sell_timestamp) VALUES
(1, 1, 1, 1, CURRENT_DATE),
(2, 2, 1, 1, CURRENT_DATE)
;

INSERT INTO reply (id, other_comment_id) VALUES
(3, 2),
(4, 2)
;

INSERT INTO reply_version (reply_id, reply_timestamp, content) VALUES
(3, CURRENT_DATE, 'Lies'),
(3, TIMESTAMP '2019-02-15 13:22:11.871+02:00', 'Lmao'),
(4, CURRENT_DATE, 'Couldnt agree more')
;

INSERT INTO review_version (review_id, review_timestamp, content, rating) VALUES
(1, CURRENT_DATE, 'Amazing', 4),
(1, TIMESTAMP '2019-02-15 13:22:11.871+02:00', 'Not really that amazing', 3),
(2, CURRENT_DATE, 'Useless', 1)
;

COMMIT;

BEGIN;

INSERT INTO complaint (id, content, status, user_id, handled_by) VALUES
(1, 'WTH', 'pending', 1, NULL),
(2, 'WTH', 'pending', 1, NULL),
(3, 'WTH', 'being_handled', 1, 1) 
;

INSERT INTO delivery_complaint (id, order_id, shop_id, product_id, sell_timestamp) VALUES
(1, 1, 1, 1, CURRENT_DATE)
;

INSERT INTO shop_complaint (id, shop_id) VALUES
(2, 1)
;

INSERT INTO comment_complaint (id, comment_id) VALUES
(3, 1)
;

COMMIT;
