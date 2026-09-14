# Operational runbook

## Onboarding failure

1. Query `onboarding_run` by `client_id`.
2. Check ADF activity output.
3. If provisioning failed, rerun provisioning only.
4. If ingestion failed, inspect `ingestion_run` and source-specific error.
5. If DQ failed, inspect `dq_result` and quarantine path.
6. Do not manually update the watermark unless the source data and target state are verified.

## SHIR failure

- Confirm both nodes are online.
- Check Windows service status.
- Confirm outbound HTTPS connectivity.
- Check source database reachability from the SHIR host.
- Verify source driver/JRE requirements.
- Re-run the failed ADF activity after the node is healthy.

## API source failure

- Check Function App logs.
- Validate token/secret in Key Vault.
- Check HTTP status and retry behavior.
- Confirm rate-limit headers.
- Re-run from the last successful watermark/page where supported.

## Data quality failure

Critical:
- duplicate business key
- schema mismatch
- unexpected row-count drop
- invalid mandatory field

Non-critical:
- optional field nulls
- warning-level freshness drift

Critical failures block promotion to curated data.
