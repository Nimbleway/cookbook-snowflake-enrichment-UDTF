# Snowflake Web Data Enrichment

A Snowflake-native cookbook that turns a list of local search queries into a rich business universe using [Nimble Web Search Agents](https://nimbleway.com). Start with a table of queries like "coffee shops in Williamsburg Brooklyn" or "gyms in Austin Texas" — get back a structured `LOCAL_BUSINESSES` table with names, categories, addresses, ratings, review counts, phone numbers, websites, coordinates, and Google Maps URLs. All from SQL.

---

## What it does

| Step | What happens | File |
|---|---|---|
| 1 | Creates the Nimble role, warehouse, database, secret, and external access integration | `01_setup.sql` |
| 2 | Installs `NIMBLE_AGENT_RUN` — a Python UDTF that calls any Nimble Web Search Agent per row | `02_nimble_agent_run.sql` |
| 3 | Seeds 20 local search queries, calls `google_maps_search` once per query, flattens results into `LOCAL_BUSINESSES` | `03_local_businesses.sql` |

---

## Quickstart

You'll need a Snowflake account with ACCOUNTADMIN access and a [Nimble API key](https://nimbleway.com).

**1.** Open `01_setup.sql`, replace `<<YOUR_NIMBLE_API_KEY>>` with your key, and run it in a Snowsight worksheet as ACCOUNTADMIN.

**2.** Open `02_nimble_agent_run.sql` in a new worksheet and run it as NIMBLE_ROLE.

**3.** Open `03_local_businesses.sql` in a new worksheet and run it. Takes 3–5 minutes.

That's it — query `LOCAL_BUSINESSES` when it finishes.

---

## Output

One Snowflake table (`LOCAL_BUSINESSES`) with ~400 rows, one per business.

| Column | Type | Description |
|---|---|---|
| `query` | STRING | The search query that generated this business |
| `category` | STRING | Label you assigned to the query |
| `name` | STRING | Business name |
| `business_category` | STRING | Google Maps business category |
| `address` | STRING | Full address |
| `street_address` | STRING | Street line only |
| `city` | STRING | City |
| `zip_code` | STRING | ZIP code |
| `rating` | NUMBER(3,2) | Google Maps rating |
| `review_count` | INTEGER | Total reviews |
| `price_level` | STRING | Price tier (e.g. `$`, `$$`) |
| `phone` | STRING | Phone number |
| `website` | STRING | Business website URL |
| `business_status` | STRING | Open / closed status |
| `sponsored` | BOOLEAN | Whether the listing is sponsored |
| `latitude` | FLOAT | Latitude |
| `longitude` | FLOAT | Longitude |
| `maps_url` | STRING | Google Maps place URL |
| `raw_entity` | VARIANT | Full Google Maps payload |
| `status` | STRING | Agent call status (`success` or error code) |
| `enriched_at` | TIMESTAMP | When the row was created |

---

## Project structure

```
├── 01_setup.sql              # Snowflake infrastructure (run once, ACCOUNTADMIN)
├── 02_nimble_agent_run.sql   # NIMBLE_AGENT_RUN UDTF (run once, NIMBLE_ROLE)
└── 03_local_businesses.sql   # Local business recipe (re-run any time)
```

---

## Going further

`NIMBLE_AGENT_RUN` works with any Nimble Web Search Agent — swap `'google_maps_search'` for `'amazon_pdp'`, `'amazon_serp'`, `'walmart_pdp'`, or any other agent in the [agent gallery](https://docs.nimbleway.com/nimble-sdk/agentic/agent-gallery). The UDTF signature stays the same; only the agent name and params change.

---

## Requirements

- Snowflake account with ACCOUNTADMIN access (for `01_setup.sql` only)
- Nimble API key — [get one here](https://nimbleway.com)
