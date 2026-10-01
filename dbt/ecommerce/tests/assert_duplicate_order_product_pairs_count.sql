-- Guards against the legitimate 33 duplicate (order_id, product_id) pairs
-- in order_items (see notebooks/01 Section 7 / sql/README.md) ever being
-- silently collapsed -- e.g. by a future upsert keyed on that pair -- or a
-- new, unexplained batch of duplicates appearing. Either direction of
-- change should be investigated, not just re-baselined.
select count(*) as dup_pairs
from (
    select order_id, product_id
    from {{ source('raw', 'order_items') }}
    group by order_id, product_id
    having count(*) > 1
) dupes
having count(*) <> 33
