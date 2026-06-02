-- ============================================================
-- Local business universe in Snowflake via Nimble Agent
-- Pattern: queries -> STITCH many google_maps_search calls -> one rich table
-- google_maps_search returns parsing:entities:SearchResult (20/query) -> FLATTEN
-- Field paths verified against live `nimble agent run --agent google_maps_search`
-- ============================================================

USE DATABASE SANDBOX;
USE SCHEMA   PUBLIC;

-- 1) Queries: each row becomes one google_maps_search call (~20 results each).
--    `query` is the full search string; `category` is a label you choose.
CREATE OR REPLACE TABLE LOCATION_QUERIES (
  query    STRING NOT NULL,
  category STRING
);

INSERT INTO LOCATION_QUERIES (query, category) VALUES
  ('coffee shops in Williamsburg Brooklyn',          'coffee'),
  ('coffee shops in Astoria Queens',                 'coffee'),
  ('coffee shops in Mission District San Francisco', 'coffee'),
  ('pizza restaurants in Chicago Loop',              'pizza'),
  ('pizza restaurants in North End Boston',          'pizza'),
  ('sushi restaurants in Downtown Seattle',          'sushi'),
  ('sushi restaurants in West Hollywood',            'sushi'),
  ('gyms in Austin Texas',                           'gym'),
  ('gyms in Midtown Manhattan',                      'gym'),
  ('yoga studios in Santa Monica',                   'yoga'),
  ('nail salons in Scottsdale Arizona',              'beauty'),
  ('hair salons in Nashville Tennessee',             'beauty'),
  ('auto repair shops in Denver Colorado',           'auto'),
  ('auto repair shops in Portland Oregon',           'auto'),
  ('dentists in Miami Florida',                      'dental'),
  ('dentists in Philadelphia',                       'dental'),
  ('veterinarians in Atlanta Georgia',               'vet'),
  ('bookstores in Portland Oregon',                  'retail'),
  ('florists in Charleston South Carolina',          'retail'),
  ('breweries in San Diego',                         'brewery');

-- 2) STITCH + enrich: one google_maps_search per query, flatten the 20 results,
--    one row per business, all fields extracted.
CREATE OR REPLACE TABLE LOCAL_BUSINESSES AS
SELECT
    q.query,
    q.category,
    p.value:position::INTEGER                            AS position,
    p.value:title::STRING                                AS name,
    p.value:business_category::STRING                    AS business_category,
    p.value:address::STRING                              AS address,
    p.value:street_address::STRING                       AS street_address,
    p.value:city::STRING                                 AS city,
    p.value:zip_code::STRING                             AS zip_code,
    p.value:review_summary:overall_rating::NUMBER(3, 2)  AS rating,
    p.value:number_of_reviews::INTEGER                   AS review_count,
    p.value:price_level::STRING                          AS price_level,
    p.value:phone_number::STRING                         AS phone,
    p.value:place_information:website_url::STRING        AS website,
    p.value:business_status::STRING                      AS business_status,
    p.value:sponsored::BOOLEAN                           AS sponsored,
    p.value:latitude::FLOAT                              AS latitude,
    p.value:longitude::FLOAT                             AS longitude,
    p.value:place_url::STRING                            AS maps_url,
    p.value                                              AS raw_entity,   -- full payload
    a.status                                             AS status,
    CURRENT_TIMESTAMP()                                  AS enriched_at
FROM LOCATION_QUERIES q,
     TABLE(NIMBLE_INTEGRATION.TOOLS.NIMBLE_AGENT_RUN(
         'google_maps_search',
         OBJECT_CONSTRUCT('query', q.query)
     )) a,
     LATERAL FLATTEN(INPUT => a.parsing:entities:SearchResult) p
WHERE a.status = 'success';

-- sanity check: how big is the universe?
SELECT COUNT(*) AS total_businesses, COUNT(DISTINCT query) AS queries
FROM LOCAL_BUSINESSES;

-- 3) SCREENSHOT query: your query list, with live Google Maps attributes joined on.
SELECT
    category,
    name,
    city,
    rating,
    review_count,
    price_level,
    phone,
    website
FROM   LOCAL_BUSINESSES
ORDER BY review_count DESC NULLS LAST;
