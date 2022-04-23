create or replace function get_worst_shops(n integer)
returns table(shop_id integer, shop_name text, num_negative_indicators integer) as
$$

declare
    curs cursor for (
        with table1 as (
            select S.id as sid, S.name as name,
            coalesce((select count(*) from refund_request O where O.shop_id = S.id 
                group by O.order_id, O.shop_id, O.product_id, O.sell_timestamp), 0) as criteria1,
            coalesce((select count(*) from shop_complaint B where B.shop_id = S.id), 0) as criteria2,
            coalesce((select count(*) from delivery_complaint C where C.shop_id = S.id
                group by C.order_id, C.shop_id, C.product_id, C.sell_timestamp), 0) as criteria3,
            coalesce((select count(*) from review D inner join review_version E on D.id = E.review_id
                where D.shop_id = S.id and E.rating = 1 and E.review_timestamp = (
                    select max(F.review_timestamp) from review_version F where F.review_id = D.id
                )), 0) as criteria4
            from shop S
        )
        select T.sid, T.name, (T.criteria1 + T.criteria2 + T.criteria3 + T.criteria4) 
        as num from table1 T order by (T.criteria1 + T.criteria2 + T.criteria3 + T.criteria4) --desc, shop_id
    );
    r record;
    i integer;
    count integer := 0;
begin
    open curs;
    loop
        fetch curs into r;
        exit when not found;
        if i = n then
            close curs;
            return;
        end if;
        shop_id = r.sid;
        shop_name = r.name;
        num_negative_indicators = r.num;
        return next;
    end loop;
    close curs;
end;

$$ language plpgsql;


-- get_worst_shops( n INTEGER )
--  Output: TABLE( shop_id INTEGER, shop_name TEXT, num_negative_indicators INTEGER )
--  Finds the N worst shops, judging by the number of negative indicators that they have
--  Each ordered product from that shop which has a refund request (regardless of status) is
-- considered as one negative indicator
-- o Multiple refund requests on the same orderline only count as one negative indicator
--  Each shop complaint (regardless of status) is considered as one negative indicator
--  Each delivery complaint (regardless of status) for a delivered product by that shop is considered
-- as one negative indicator
-- o Multiple complaints on the same orderline only count as one negative indicator
--  Each 1-star review is considered as one negative indicator
-- o Only consider the latest version of the review
-- o i.e., if there is a previous version that is 1-star but the latest version is 2-star, then we
-- do not consider this as a negative indicator
--  Results should be ordered descending by num_negative_indicators (the total number of all
-- negative indicators listed above)
-- o In the case of a tie in num_negative_indicators, order them ascending by shop_id