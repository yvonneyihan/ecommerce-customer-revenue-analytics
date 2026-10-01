select
    customer_id,
    country,
    signup_date
from {{ source('raw', 'customers') }}
