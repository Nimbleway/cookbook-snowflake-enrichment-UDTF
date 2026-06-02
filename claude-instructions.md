# Claude Code Instructions — Snowflake Web Data Enrichment (UDTF)

You are helping the user set up and run the Snowflake Web Data Enrichment cookbook. Follow these steps in order. Check each prerequisite before proceeding. Tell the user what you're doing at each step.

---

## Step 1: Check prerequisites

Confirm the user has both of the following before continuing.

**Snowflake account with ACCOUNTADMIN access**
Tell the user: Step 2 creates a role, warehouse, database, secret, and external access integration — all require ACCOUNTADMIN. After setup, everything runs as the lighter `NIMBLE_ROLE`.

If the user is not sure whether they have ACCOUNTADMIN, ask them to run this in a Snowsight worksheet:
```sql
SELECT CURRENT_ROLE();
```

**Nimble API key**
Get one at: https://nimbleway.com
Tell the user: the key is stored as a Snowflake Secret and never leaves their Snowflake environment.

---

## Step 2: Clone the repo

Check whether the repo is already cloned locally:

```bash
ls cookbook-snowflake-enrichment-UDTF
```

**If the directory exists** — navigate into it and pull the latest:
```bash
cd cookbook-snowflake-enrichment-UDTF
git pull
```

**If it does not exist** — clone it:
```bash
git clone https://github.com/Nimbleway/cookbook-snowflake-enrichment-UDTF
cd cookbook-snowflake-enrichment-UDTF
```

---

## Step 3: Configure the API key

Ask the user for their Nimble API key.

Open `01_setup.sql` and replace the placeholder:
```
SECRET_STRING = '<<YOUR_NIMBLE_API_KEY>>'
```
with the user's actual key:
```
SECRET_STRING = 'their_actual_key_here'
```

Confirm the replacement and show the user the updated line.

---

## Step 4: Run the setup script

Tell the user: open Snowsight (app.snowflake.com), create a new worksheet, paste the full contents of `01_setup.sql`, and click **Run All**.

Read `01_setup.sql` and display it so the user can copy it. Tell them what this step creates:
- `NIMBLE_ROLE` — the role that owns the Nimble integration
- `NIMBLE_INTEGRATION` database with `TOOLS`, `AGENTS`, and `RECIPES` schemas
- `NIMBLE_AGENT_WH` — dedicated XSMALL warehouse (auto-suspends after 60 seconds)
- `NIMBLE_API_RULE` — network rule that locks egress to `sdk.nimbleway.com`
- `NIMBLE_API_KEY` — Snowflake Secret holding the API key
- `NIMBLE_API_ACCESS` — external access integration that wires the rule and secret together

Expected runtime: ~10 seconds. The final output is a `SHOW INTEGRATIONS` result confirming `NIMBLE_API_ACCESS` is active.

Ask the user to confirm the script ran without errors before continuing.

---

## Step 5: Install the NIMBLE_AGENT_RUN UDTF

Tell the user: open a new Snowsight worksheet, paste the full contents of `02_nimble_agent_run.sql`, and click **Run All**.

Read `02_nimble_agent_run.sql` and display it so the user can copy it. Tell them what this step creates:
- `NIMBLE_INTEGRATION.TOOLS.NIMBLE_AGENT_RUN(agent_name, params)` — a Python UDTF that sends each row to any Nimble Web Search Agent and returns the response as typed Snowflake columns: `task_id`, `status`, `status_code`, `url`, `parsing`, `warnings`, `raw`

Expected runtime: ~5 seconds.

Ask the user to confirm the script ran without errors before continuing.

---

## Step 6: Build the local business universe

Tell the user: open a new Snowsight worksheet, paste the full contents of `03_local_businesses.sql`, and click **Run All**.

Read `03_local_businesses.sql` and display it so the user can copy it.

Tell the user what to expect:
1. A `LOCATION_QUERIES` table is created with 20 local search queries across US cities and business categories
2. The enrichment query calls `google_maps_search` once per query via `NIMBLE_AGENT_RUN`
3. Results are flattened from `parsing:entities:SearchResult` (up to 20 businesses per query)
4. The final `LOCAL_BUSINESSES` table lands with ~400 enriched businesses

Expected runtime: 3–5 minutes. The sanity check query at the end of the script shows total businesses and queries completed. Show that result to the user.

---

## Step 7: Explore the results

The browse query at the bottom of `03_local_businesses.sql` shows all businesses ranked by review count with name, city, rating, price level, phone, and website.

Suggest a few things the user can try next:
- Edit `LOCATION_QUERIES` to add their own search queries (any city, any category) and re-run the `CREATE TABLE LOCAL_BUSINESSES` block to enrich the new queries
- Use `LATERAL FLATTEN` on the `raw_entity` column to extract additional fields from the full Google Maps payload
- Join `LOCAL_BUSINESSES` with other Snowflake tables using `city`, `zip_code`, or `latitude`/`longitude`
- Swap `'google_maps_search'` for any other Nimble Web Search Agent — `'amazon_pdp'`, `'walmart_pdp'`, `'amazon_serp'`, etc. — `NIMBLE_AGENT_RUN` works with all of them

---

## Notes

- `03_local_businesses.sql` uses `USE DATABASE SANDBOX` by default. If the user wants to write the output tables to a different database, they should change that line before running.
- Errors from the Nimble API surface as rows with `status = 'http_<code>'` rather than failing the entire query. To diagnose issues: `SELECT * FROM LOCAL_BUSINESSES WHERE status != 'success'`.
- The full Google Maps payload is stored in `raw_entity` as a Snowflake VARIANT — useful for extracting additional fields without re-running the enrichment.
- `NIMBLE_AGENT_RUN` is a UDTF (table function), not a stored procedure. It is not compatible with Snowflake Cortex Agent custom tools — those require scalar UDFs or stored procedures.
