# Azure ADF Automated Client Onboarding

Reference implementation for an end-to-end Azure Data Factory onboarding platform:

UI/API -> onboarding service -> metadata/control DB -> ADF master pipeline
-> resource/artifact provisioning -> parallel source ingestion
-> raw storage -> validation -> curated SQL -> audit/monitoring.

## Assumptions

- Azure Data Factory is the orchestration layer.
- Azure SQL Database stores client metadata, source configuration, watermarks, audit state, and DQ results.
- ADLS Gen2 is the lake with `raw/`, `quarantine/`, and `curated/` zones.
- On-prem SQL Server/legacy databases use Self-Hosted Integration Runtime (SHIR).
- REST/SaaS sources use an Azure Function ingestion API.
- Azure Key Vault stores secrets.
- Managed identities are preferred over embedded credentials.
- The platform uses shared Azure resources with tenant/client isolation rather than creating an entire resource group per client.
- ADF deployment is assumed to be CI/CD controlled.

## Repository layout

```text
infra/
  main.bicep
  parameters.dev.json
sql/
  001_schema.sql
  002_stored_procedures.sql
functions/
  onboarding_api/
    function_app.py
    requirements.txt
adf/
  pipelines/
    PL_ONBOARD_CLIENT.json
    PL_INGEST_TABLE.json
    PL_VALIDATE_DATA.json
  datasets/
    DS_SQL_SOURCE.json
    DS_ADLS_RAW.json
  linkedServices/
    LS_AZURE_SQL.json
    LS_ADLS.json
    LS_SHIR_SQL.json
docs/
  architecture.md
  runbook.md
```

## Deployment order

1. Deploy Azure infrastructure from `infra/`.
2. Create SQL objects from `sql/`.
3. Deploy the Function App and assign its managed identity the required RBAC.
4. Install/register SHIR on a dedicated Windows VM for private sources.
5. Deploy ADF linked services, datasets and pipelines.
6. Configure Key Vault references/secrets for any source credentials.
7. Connect the client UI to the onboarding API.
8. Run an onboarding request and monitor the ADF master pipeline.

## Onboarding flow

1. UI sends `POST /api/onboard`.
2. API validates the client payload and creates/updates the client record.
3. API provisions tenant-scoped artifacts such as ADLS container/folder and metadata rows.
4. API starts `PL_ONBOARD_CLIENT` with `client_id`.
5. ADF reads enabled sources from control tables.
6. Each source is routed to the correct integration runtime:
   - private/on-prem -> SHIR
   - cloud/public API -> Azure Function/API layer
7. Initial load performs full historical extraction.
8. Subsequent loads use a watermark or source CDC/change tracking.
9. Data lands in raw storage.
10. Validation checks schema, nulls, duplicate business keys, row counts and freshness.
11. Failed records are quarantined; critical validation failures fail the pipeline.
12. Successful loads update watermarks and audit status.

## Production hardening

- Use separate ADF/Function/Storage/SQL resources per environment.
- Use managed identities and Key Vault; do not put secrets in pipeline JSON.
- Run at least two SHIR nodes for HA.
- Add private endpoints where the network model requires them.
- Use retry + timeout policies for API calls.
- Make onboarding idempotent using a client/business key.
- Never advance a watermark until the downstream load and validation succeed.
- Send ADF/Function/SQL diagnostics to Log Analytics/Azure Monitor.
- Put ADF JSON/Bicep/SQL in Git and deploy through CI/CD.
