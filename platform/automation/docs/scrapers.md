🔌 How Scrapers Connect to n8n Workflows

  Step 1: Scrapers Populate Database (Daily)

  6:00 AM ET - Business License Scraper runs
  # scrapers.energov_business_licenses
  INSERT INTO leads.business_licenses (
    company_name, address_full, apply_date, ...
  ) VALUES (...);

  6:30 AM ET - Home Sales Scraper runs
  # scrapers.charleston_sales
  INSERT INTO leads.home_sales (
    buyer_name, property_address, sale_price, sale_date, ...
  ) VALUES (...);

  Step 2: n8n Workflows Read from Database (30 min later)

  In n8n, you need to:

  1. Create a Postgres Credential (one-time setup)
    - In n8n UI: Settings → Credentials → Add Credential → Postgres
    - Host: automation-pg-rw.automation.svc.cluster.local
    - Port: 5432
    - Database: leads
    - User: scrapers (from secret)
    - Password: (from secret automation-pg-scrapers-secret)
  2. Replace HTTP nodes with Postgres nodes in each workflow:

  Home Sales Monitor Workflow

  Replace these TODO nodes:
  ❌ "Fetch Charleston County RMC Deeds (TODO)" (HTTP Request)
  ❌ "Fetch Berkeley County ROD Deeds (TODO)" (HTTP Request)
  ❌ "Fetch Dorchester County ROD Deeds (TODO)" (HTTP Request)

  With this:
  ✅ "Fetch Recent Home Sales" (Postgres Node)

  Postgres Query:
  SELECT
    buyer_name,
    property_address,
    sale_price,
    sale_date,
    bedrooms,
    full_baths,
    half_baths,
    finished_sqft,
    year_built,
    county
  FROM leads.home_sales
  WHERE sale_date >= CURRENT_DATE - INTERVAL '1 day'
  ORDER BY sale_date DESC;

  Output format: The Postgres node will return JSON like:
  [
    {
      "buyer_name": "SMITH JOHN & JANE",
      "property_address": "123 MAIN ST CHARLESTON SC 29401",
      "sale_price": 450000,
      "sale_date": "2026-05-20T00:00:00.000Z",
      "bedrooms": 3,
      "full_baths": 2,
      "half_baths": 1,
      "finished_sqft": 1800,
      "year_built": 2010,
      "county": "Charleston"
    },
    ...
  ]

  Business Directory Monitor Workflow

  Replace these TODO nodes:
  ❌ "Fetch SC SOS Business Filings (TODO)" (HTTP Request)
  ❌ "Fetch Charleston Chamber Directory (TODO)" (HTTP Request)

  With this:
  ✅ "Fetch Recent Business Licenses" (Postgres Node)

  Postgres Query:
  SELECT
    company_name,
    dba,
    business_type,
    address_full,
    address_city,
    apply_date,
    license_type,
    license_status
  FROM leads.business_licenses
  WHERE apply_date >= CURRENT_DATE - INTERVAL '1 day'
    AND address_city IN ('Charleston', 'Mount Pleasant', 'North Charleston',
                         'Summerville', 'West Ashley', 'James Island',
                         'Daniel Island', 'Folly Beach')
  ORDER BY apply_date DESC;

  Step 3: Process Data (Same as Before)

  The existing workflow logic already does:
  - ✅ Classify by price tier / business type
  - ✅ Deduplicate
  - ✅ Build HTML digest
  - ✅ Send email

  You just need to replace the data source (HTTP → Postgres).

  📝 Workflow Update Checklist

  Here's what needs to change in each n8n workflow:

  Charleston Home Sales Monitor

  - Add Postgres credential to n8n
  - Delete 3 "Fetch ... Deeds (TODO)" HTTP nodes
  - Delete 3 "Normalize ... Items" Code nodes
  - Add 1 "Fetch Recent Home Sales" Postgres node with query above
  - Update "Merge All Counties" node → remove (no longer merging 3 sources)
  - Connect Postgres node directly to "Filter to Sale Deeds" node
  - Test workflow

  Charleston Business Directory Monitor

  - Delete 2 "Fetch ... (TODO)" HTTP nodes
  - Delete 2 "Normalize ... Items" Code nodes
  - Add 1 "Fetch Recent Business Licenses" Postgres node with query above
  - Update "Merge All Sources" node → remove (no longer merging 2 sources)
  - Connect Postgres node directly to "Classify Business Type and Products" node
  - Test workflow

  Charleston Life-Event Monitor

  - Replace "Fetch SC SOS Business Filings (TODO)" HTTP node
  - Add Postgres node querying leads.business_licenses
  - Keep RSS nodes (those are fine)
  - Test workflow

  🎯 Why This Architecture?

  Benefits:
  1. Separation of concerns: Scrapers collect data, workflows process/notify
  2. Reliability: Scraper failures don't break workflows
  3. Reusability: Multiple workflows can query the same data
  4. Performance: Database queries are fast, no external API calls in workflows
  5. Audit trail: All scraped data is stored with timestamps

  Data Flow Timeline:
  6:00 AM → Scraper runs → DB populated
  6:30 AM → Scraper runs → DB populated
  7:00 AM → n8n workflow queries DB → processes → emails
  7:30 AM → n8n workflow queries DB → processes → emails
  8:00 AM → n8n workflow queries DB → processes → emails
