create or replace function get_most_returned_products_from_manufacturer( 
    manufacturer_id INTEGER, n INTEGER)
returns TABLE ( 
    product_id INTEGER, product_name TEXT, return_rate NUMERIC(3, 2) 
) as $$
declare
    curs cursor for (
        -- each product and their corresponding manufacturer
        with table1 as (
            select P.id, P.name, coalesce(sum(quantity), 0) as val from product P left outer join orderline O
            on P.id = O.product_id where P.manufacturer = 1 and O.status = 'delivered'
            group by P.id, P.name
        ), table2 as (
            select P.id, P.name, coalesce(sum(quantity), 0) as val from product P left outer join refund_request R
            on P.id = R.product_id where P.manufacturer = 1 and R.status = 'accepted'
            group by P.id, P.name
        ) select T1.id as id, T1.name as name, (T2.val / T1.val) as ratio from table1 T1 full outer join 
        table2 T2 on T1.id = T2.id and T1.name = T2.name order by (T2.val / T1.val)--, product_id 
        -- 2 decimal places??
    );
    r record;
    i integer := 0;
begin
    open curs;
    loop
        fetch curs into r;
        exit when not found;
        i := i + 1;
        if i = n then
            close curs;
            return;
        end if;
        product_id := r.id;
        product_name := r.name;
        return_rate := r.ratio;
        return next;
    end loop;
    close curs;
end;

$$ language plpgsql;