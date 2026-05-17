# BigQuery + GA4 Analysis

[![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=flat&logo=google-cloud&logoColor=white)](https://cloud.google.com/bigquery)
[![SQL](https://img.shields.io/badge/SQL-336791?style=flat&logo=postgresql&logoColor=white)](https://cloud.google.com/bigquery/docs/reference/standard-sql)

## Overview

Two sets of SQL queries written in BigQuery against the public Google Analytics 4 sample dataset (`bigquery-public-data.ga4_obfuscated_sample_ecommerce`). The dataset contains obfuscated event-level data from the Google Merchandise Store.

The project covers two distinct analytical directions: funnel and conversion analysis across traffic channels and landing pages, and structured exploration of GA4's nested data model using UNNEST, window functions, and partitions.

## Dataset

`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

Event-based GA4 export with nested RECORD fields: `event_params`, `user_properties`, `items`. Data spans 2020–2021.

## Part 1 — Funnel Analysis

**File:** `funnel_analysis/funnel_queries.sql`

Three queries covering the full analytical pipeline from raw event extraction to conversion analysis.

### Query 1: Event Data Preparation

Extracts funnel events for 2021 with session IDs, user identifiers, device category, geography, and traffic source. Covers seven funnel stages: `session_start`, `view_item`, `add_to_cart`, `begin_checkout`, `add_shipping_info`, `add_payment_info`, `purchase`.

Session ID is extracted from the nested `event_params` array using a correlated subquery.

### Query 2: Conversion Rates by Date and Traffic Channel

Calculates session-to-purchase funnel conversions grouped by date, source, medium, and campaign.

Sessions are counted as unique `user_pseudo_id + session_id` combinations to avoid double-counting across users with shared session IDs.

| Metric | Description |
|---|---|
| `user_sessions_count` | Unique sessions per date and channel |
| `visit_to_cart` | Session → add to cart |
| `visit_to_checkout` | Session → begin checkout |
| `visit_to_purchase` | Session → purchase |

Pivot logic implemented with `COUNT(DISTINCT CASE WHEN ...)` across a single CTE scan.

### Query 3: Conversion by Landing Page (2020)

Compares session-to-purchase conversion rates across landing pages. Page paths are extracted from `page_location` in `session_start` events and cleaned with `REGEXP_REPLACE` to remove domain and query parameters.

Sessions and purchases are joined by `user_pseudo_id + session_id`. Pages with fewer than 50 sessions are excluded.

Top results from 2020 data:

| Page | Sessions | Purchases | Conversion |
|---|---|---|---|
| /revieworder.html | 74 | 19 | 25.7% |
| /payment.html | 200 | 51 | 25.5% |
| /basket.html | 2,651 | 194 | 7.3% |
| /Google+Redesign/Apparel/Womens | 907 | 45 | 5.0% |

`/basket.html` is the primary drop-off point in the funnel — highest session volume with significantly lower conversion than checkout pages.

## Part 2 — GA4 Data Exploration

**File:** `ga4_data_exploration/data_exploration.sql`

Ten queries exploring GA4's nested data structure on `events_20210131` and `events_2021*`.

| Query | Focus |
|---|---|
| 1–2 | View REPEATED fields and array sizes for a single user |
| 3 | UNNEST `event_params` to flat key-value rows |
| 4 | Event parameter frequency across full 2021 dataset |
| 5 | UNNEST `items` array with product-level fields |
| 6 | Product revenue summary: event count, quantity, total revenue |
| 7 | Filter events by item category using `EXISTS` |
| 8 | Daily user, event, and purchase counts via `_TABLE_SUFFIX` partitions |
| 9 | Top 20 users by spend with `RANK`, `DENSE_RANK`, `ROW_NUMBER` |
| 10 | First event per session using `ROW_NUMBER OVER (PARTITION BY user, session)` |

Query 10 identifies the most frequent session-starting event across all sessions on `events_20210131`.

## Key Techniques

- Correlated subqueries inside SELECT for extracting scalar values from `event_params`
- `UNNEST` with `CROSS JOIN` for flattening ARRAY of STRUCT fields
- `EXISTS` with subquery for filtering on nested array values
- `REGEXP_REPLACE` for URL parsing and path extraction
- `_TABLE_SUFFIX` for partition-aware queries across date-sharded tables
- `COUNT(DISTINCT CASE WHEN ...)` for multi-event pivot without PIVOT syntax
- `ROW_NUMBER OVER (PARTITION BY user_pseudo_id, ga_session_id)` for session event ordering
- `RANK`, `DENSE_RANK`, `ROW_NUMBER` applied together for user spend ranking

## Files

```
bigquery-ga4-analysis/
├── funnel_analysis/
│   └── funnel_queries.sql
├── ga4_data_exploration/
│   └── data_exploration.sql
└── README.md
```
