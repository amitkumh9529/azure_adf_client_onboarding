# Architecture

```text
                    +----------------------+
                    | Client Web UI         |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | Onboarding API        |
                    | Azure Function App    |
                    +----+-------------+----+
                         |             |
                         |             +--> Azure resources/artifacts
                         |                  (ADLS container/folders)
                         v
                  +--------------+
                  | Azure SQL    |
                  | Control DB   |
                  +------+-------+
                         |
                         | Execute pipeline
                         v
                  +--------------+
                  | Azure Data   |
                  | Factory       |
                  +--+--------+--+
                     |        |
          private ---+        +--- public/SaaS
                     |                 |
                     v                 v
                +---------+       +-----------+
                | SHIR    |       | Function  |
                +----+----+       | API layer |
                     |            +-----+-----+
                     v                  |
                On-prem DB              v
                                  Third-party API
                     |
                     +----------+
                                v
                         +-------------+
                         | ADLS Gen2   |
                         | raw/quarantine/
                         | curated     |
                         +------+------+
                                |
                                v
                         +-------------+
                         | Azure SQL / |
                         | Warehouse   |
                         +-------------+

Cross-cutting:
- Key Vault for secrets
- Managed identities/RBAC
- Azure Monitor + Log Analytics
- Git/CI/CD
```

## Why this design

ADF remains the orchestrator; extraction logic is kept close to each source type. SHIR is appropriate for private/on-premises stores, while cloud API extraction is isolated in a Function so pagination, authentication, throttling and source-specific behavior do not pollute ADF expressions.

A metadata-driven model avoids creating one pipeline per client/table. One master pipeline reads the source configuration and passes parameters to reusable ingestion and validation pipelines.

## Incremental loading

Preferred order:

1. Native CDC/change tracking if the source supports it.
2. Reliable `last_modified` watermark.
3. Monotonic integer key where updates are not required.
4. Full load only when the source cannot provide a safe delta.

The watermark is advanced only after copy + validation + downstream commit succeeds.
