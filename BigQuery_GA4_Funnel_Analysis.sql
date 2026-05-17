-- Query 1: Event data preparation: funnel stages with session ID, device, geography, traffic source
SELECT 
  timestamp_micros(event_timestamp) AS event_timestamp
  , user_pseudo_id
  , (select value.int_value from e.event_params where key = 'ga_session_id') AS session_id
  , event_name
  , geo.country
  , device.category
  , traffic_source.source
  , traffic_source.medium
  , traffic_source.name
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_2021*` e
WHERE event_name IN (
  'session_start'
  , 'view_item'
  , 'add_to_cart'
  , 'begin_checkout'
  , 'add_shipping_info'
  , 'add_payment_info'
  , 'purchase')
LIMIT 100;

-- Query 2: Funnel conversion rates by date and traffic channel
WITH cte1 AS (
  SELECT 
    EXTRACT(DATE FROM TIMESTAMP_MICROS(event_timestamp)) AS event_date
    , traffic_source.source
    , traffic_source.medium
    , traffic_source.name AS campaign
    , event_name
    , user_pseudo_id || CAST((SELECT ee.value.int_value FROM UNNEST(event_params) ee WHERE ee.key = 
    'ga_session_id') AS STRING) AS user_session
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
  WHERE event_name IN ('session_start', 'add_to_cart', 'begin_checkout', 'purchase')
), 
counted_data AS (
  SELECT 
    event_date
    , source
    , medium
    , campaign
    , COUNT (DISTINCT user_session) AS user_session_count
    , COUNT (DISTINCT CASE WHEN event_name = 'session_start'  THEN user_session END) AS count_session_start
    , COUNT (DISTINCT CASE WHEN event_name = 'add_to_cart'    THEN user_session END) AS count_add_to_cart 
    , COUNT (DISTINCT CASE WHEN event_name = 'begin_checkout' THEN user_session END) AS count_begin_checkout
    , COUNT (DISTINCT CASE WHEN event_name = 'purchase'       THEN user_session END) AS count_purchase
  FROM cte1
  GROUP BY 1, 2, 3, 4
)
SELECT 
  event_date
  , source
  , medium
  , campaign 
  , count_session_start                        AS user_sessions_count
  , count_add_to_cart    / count_session_start AS visit_to_cart
  , count_begin_checkout / count_session_start AS visit_to_checkout
  , count_purchase       / count_session_start AS visit_to_purchase 
FROM counted_data
LIMIT 100;

-- Query 3: Session-to-purchase conversion by landing page (2020)
WITH session_starts AS (
    SELECT
        user_pseudo_id,
        (SELECT value.int_value 
         FROM UNNEST(event_params) 
         WHERE key = 'ga_session_id') AS session_id,
        (SELECT value.string_value 
         FROM UNNEST(event_params) 
         WHERE key = 'page_location') AS page_location
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_2020*`
    WHERE event_name = 'session_start'
),
purchases AS (
    SELECT
        user_pseudo_id,
        (SELECT value.int_value 
         FROM UNNEST(event_params) 
         WHERE key = 'ga_session_id') AS session_id
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_2020*`
    WHERE event_name = 'purchase'
),
page_paths AS (
    SELECT
        user_pseudo_id,
        session_id,
        REGEXP_REPLACE(
            REGEXP_REPLACE(page_location, r'https?://[^/]+', ''),
            r'\?.*', ''
        ) AS page_path
    FROM session_starts
    WHERE page_location IS NOT NULL
)
SELECT
    page_path,
    COUNT(DISTINCT p.user_pseudo_id || CAST(p.session_id AS STRING)) AS total_sessions,
    COUNT(DISTINCT pu.user_pseudo_id || CAST(pu.session_id AS STRING)) AS total_purchases,
    ROUND(
        COUNT(DISTINCT pu.user_pseudo_id || CAST(pu.session_id AS STRING)) /
        COUNT(DISTINCT p.user_pseudo_id || CAST(p.session_id AS STRING)),
        4
    ) AS session_to_purchase
FROM page_paths p
LEFT JOIN purchases pu
    ON p.user_pseudo_id = pu.user_pseudo_id
    AND p.session_id = pu.session_id
GROUP BY page_path
HAVING total_sessions >= 50
ORDER BY session_to_purchase DESC
LIMIT 20;