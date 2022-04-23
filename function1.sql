create or replace function view_comments(
    in shop_id INTEGER, in product_id INTEGER, 
    in sell_timestamp TIMESTAMP 
) returns table(
    username varchar, content varchar,
    rating integer, comment_timestamp TIMESTAMP)
as $$
declare
    curs cursor for (
        -- select all reviews of the targeted product by the user
        -- is this only for one user? we want all review for the product right?
        with table1 as (select C.id as cid, U.id as uid, U.name as name, U.account_closed as status,
        (select review_timestamp from review_version Ra where Ra.review_id = C.id order by review_timestamp limit 1) as timing,
        (select content from review_version Rb where Rb.review_id = C.id order by review_timestamp limit 1) as content,
        (select rating from review_version Rc where Rc.review_id = C.id order by review_timestamp limit 1) as rating
        from comment C inner join users U on C.user_id = U.id
        where exists (select * from review R1 where R1.id = C.id and
        R1.shop_id = shop_id and R1.product_id = product_id and R1.sell_timestamp = sell_timestamp)
        ),
        -- select all replies of the target reviews
        table2 as (select C.id as cid, U.id as uid, U.name as name, U.account_closed as status,
        (select reply_timestamp from reply_version Ra where Ra.reply_id = C.id order by reply_timestamp limit 1) as timing,
        (select content from reply_version Rb where Rb.reply_id = C.id order by reply_timestamp limit 1) as content,
        NULL as rating
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
            username := 'Deleted Account'; -- 'A Deleted User'
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