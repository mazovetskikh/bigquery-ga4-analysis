-- View all REPEATED fields for a single user
WITH single_user AS
(
    SELECT user_pseudo_id, 
           event_timestamp
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
    WHERE EXISTS(SELECT 1 
                 FROM UNNEST(items) i 
                 WHERE i.item_name IS NOT NULL 
                 AND i.item_name <> "(not set)")
    ORDER BY user_pseudo_id, event_timestamp
    LIMIT 1
)
SELECT s.user_pseudo_id,
       TIMESTAMP_MICROS(s.event_timestamp) event_timestamp,
       main.event_name,
       main.event_params,
       main.user_properties,
       main.items
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` main
RIGHT JOIN single_user s 
USING (user_pseudo_id, event_timestamp);

-- Array size measurement: event_params, user_properties, items
WITH single_user AS
(
    SELECT user_pseudo_id, 
           event_timestamp
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
    WHERE EXISTS(SELECT 1 
                 FROM UNNEST(items) i 
                 WHERE i.item_name IS NOT NULL 
                 AND i.item_name <> "(not set)")
    ORDER BY user_pseudo_id, event_timestamp
    LIMIT 1
)
SELECT s.user_pseudo_id,
       TIMESTAMP_MICROS(s.event_timestamp) event_timestamp,
       main.event_name,
       main.event_params,
       main.user_properties,
       main.items, 
       ARRAY_LENGTH(event_params) event_params_count,
       ARRAY_LENGTH(user_properties) properties_count,
       ARRAY_LENGTH(items) items_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` main
RIGHT JOIN single_user s 
USING (user_pseudo_id, event_timestamp);

-- Unnest event_params to flat key-value structure
WITH single_user AS
(
    SELECT user_pseudo_id, 
           event_timestamp
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
    WHERE EXISTS(SELECT 1 
                 FROM UNNEST(items) i 
                 WHERE i.item_name IS NOT NULL 
                 AND i.item_name <> "(not set)")
    ORDER BY user_pseudo_id, event_timestamp
    LIMIT 1
)
SELECT s.user_pseudo_id,
       event_name,
       key,
       value.string_value,
       value.int_value,
       value.double_value
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131` main
CROSS JOIN UNNEST (event_params) e
RIGHT JOIN single_user s USING (user_pseudo_id, event_timestamp)
ORDER BY key;

-- Event parameter frequency across 2021 dataset
SELECT key,
       count(*)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_2021*`,
UNNEST (event_params) e
GROUP BY key
ORDER BY 2 DESC;

-- Unnest items array with product-level fields
SELECT user_pseudo_id,
       TIMESTAMP_MICROS(event_timestamp) event_timestamp,
       item_id,
       item_name,
       item_category,
       price,
       quantity
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
UNNEST(items) i;

-- Product revenue summary: event count, quantity, total revenue
SELECT item_name,
       COUNT(event_name) event_count,
       SUM(quantity) total_quantity,
       SUM(price * quantity) total_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
UNNEST(items) i
WHERE item_name <> "(not set)"
GROUP BY item_name
ORDER BY 4 DESC;

-- Filter events by item category using EXISTS
SELECT DISTINCT event_name
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
WHERE EXISTS (SELECT 1 
              FROM UNNEST(items) i 
              WHERE i.item_category = 'Apparel');

-- Daily metrics by partition date using _TABLE_SUFFIX
SELECT _TABLE_SUFFIX date,
       COUNT(DISTINCT user_pseudo_id) total_users,
       COUNT(event_name) total_events,
       COUNTIF(event_name = "purchase") total_purchases
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY date
ORDER BY date;

-- Top 20 users by total spend with RANK, DENSE_RANK, ROW_NUMBER
SELECT user_pseudo_id,
       SUM(price * quantity) total_spend,
       RANK()       OVER (ORDER BY SUM(price * quantity) DESC) rank_no_dense,
       DENSE_RANK() OVER (ORDER BY SUM(price * quantity) DESC) rank_dense,
       ROW_NUMBER() OVER (ORDER BY SUM(price * quantity) DESC) row_num
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
UNNEST(items) i
GROUP BY user_pseudo_id
HAVING total_spend IS NOT NULL
ORDER BY total_spend DESC
LIMIT 20;

-- First event per session using ROW_NUMBER with PARTITION BY
WITH session_id AS
(
    SELECT user_pseudo_id, 
           event_name,
           (SELECT value.int_value FROM UNNEST(event_params) WHERE key = "ga_session_id") ga_session_id,
           event_timestamp
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
), window_functions AS
(
    SELECT user_pseudo_id,
           ga_session_id,
           event_name,
           ROW_NUMBER() OVER(PARTITION BY user_pseudo_id, ga_session_id ORDER BY event_timestamp) session_event_num
    FROM session_id
) 
SELECT event_name AS most_frequent_event 
FROM (SELECT event_name
      FROM window_functions
      WHERE session_event_num = 1
      GROUP BY 1
      ORDER BY COUNT(event_name) DESC 
      LIMIT 1);

