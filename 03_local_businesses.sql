/*
 * 03_local_businesses.sql — local business universe via Nimble google_maps_search
 *
 * Role:        NIMBLE_ROLE (or any role with access to NIMBLE_INTEGRATION.TOOLS)
 * Creates:     LOCATION_QUERIES, LOCAL_BUSINESSES
 * Prereq:      01_setup.sql and 02_nimble_agent_run.sql have run successfully
 * Runtime:     3–5 minutes (20 google_maps_search calls, sequential in the lateral join)
 *
 * Pattern: queries → NIMBLE_AGENT_RUN('google_maps_search', ...) → LATERAL FLATTEN
 * google_maps_search returns up to 20 businesses per query under
 * parsing:entities:SearchResult. Field paths are verified against live responses.
 *
 * Change USE DATABASE / USE SCHEMA below to target your preferred database.
 */

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

-- 2) Enrich: one google_maps_search per query, flatten the results,
--    one row per business, all fields extracted.
CREATE OR REPLACE TABLE LOCAL_BUSINESSES AS
SELECT
    q.query,
    q.category,
    p.value:position::INTEGER                           AS position,
    p.value:title::STRING                               AS name,
    p.value:business_category::STRING                   AS business_category,
    p.value:address::STRING                             AS address,
    p.value:street_address::STRING                      AS street_address,
    p.value:city::STRING                                AS city,
    p.value:zip_code::STRING                            AS zip_code,
    p.value:review_summary:overall_rating::NUMBER(3,2)  AS rating,
    p.value:number_of_reviews::INTEGER                  AS review_count,
    p.value:price_level::STRING                         AS price_level,
    p.value:phone_number::STRING                        AS phone,
    p.value:place_information:website_url::STRING       AS website,
    p.value:business_status::STRING                     AS business_status,
    p.value:sponsored::BOOLEAN                          AS sponsored,
    p.value:latitude::FLOAT                             AS latitude,
    p.value:longitude::FLOAT                            AS longitude,
    p.value:place_url::STRING                           AS maps_url,
    p.value                                             AS raw_entity,
    a.status                                            AS status,
    CURRENT_TIMESTAMP()                                 AS enriched_at
FROM LOCATION_QUERIES q,
     TABLE(NIMBLE_INTEGRATION.TOOLS.NIMBLE_AGENT_RUN(
         'google_maps_search',
         OBJECT_CONSTRUCT('query', q.query)
     )) a,
     LATERAL FLATTEN(INPUT => a.parsing:entities:SearchResult) p
WHERE a.status = 'success';

-- Sanity check: how many businesses did we collect?
SELECT COUNT(*) AS total_businesses, COUNT(DISTINCT query) AS queries_run
FROM LOCAL_BUSINESSES;

-- Browse results ranked by review count.
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
ORDER  BY review_count DESC NULLS LAST;
