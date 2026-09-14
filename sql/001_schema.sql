CREATE SCHEMA onboarding;
GO
CREATE SCHEMA control;
GO
CREATE SCHEMA audit;
GO
CREATE SCHEMA dq;
GO

CREATE TABLE onboarding.client (
    client_id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    client_name NVARCHAR(200) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'REGISTERED',
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE control.source_config (
    source_id BIGINT IDENTITY PRIMARY KEY,
    client_id UNIQUEIDENTIFIER NOT NULL,
    source_name NVARCHAR(200) NOT NULL,
    source_type VARCHAR(30) NOT NULL, -- SQL / API
    linked_service_name NVARCHAR(200) NULL,
    function_route NVARCHAR(500) NULL,
    schema_name NVARCHAR(128) NULL,
    table_name NVARCHAR(128) NULL,
    business_key NVARCHAR(500) NULL,
    watermark_column NVARCHAR(128) NULL,
    watermark_type VARCHAR(30) NULL,
    current_watermark NVARCHAR(200) NULL,
    enabled BIT NOT NULL DEFAULT 1,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_source_client FOREIGN KEY (client_id)
        REFERENCES onboarding.client(client_id)
);
GO

CREATE TABLE audit.ingestion_run (
    ingestion_run_id BIGINT IDENTITY PRIMARY KEY,
    client_id UNIQUEIDENTIFIER NOT NULL,
    source_id BIGINT NOT NULL,
    pipeline_run_id NVARCHAR(100) NULL,
    started_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    completed_at DATETIME2(3) NULL,
    status VARCHAR(30) NOT NULL,
    rows_read BIGINT NULL,
    rows_written BIGINT NULL,
    old_watermark NVARCHAR(200) NULL,
    new_watermark NVARCHAR(200) NULL,
    error_message NVARCHAR(MAX) NULL
);
GO

CREATE TABLE dq.result (
    dq_result_id BIGINT IDENTITY PRIMARY KEY,
    client_id UNIQUEIDENTIFIER NOT NULL,
    source_id BIGINT NULL,
    ingestion_run_id BIGINT NULL,
    rule_name NVARCHAR(200) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    passed BIT NOT NULL,
    failed_rows BIGINT NULL,
    checked_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    details NVARCHAR(MAX) NULL
);
GO

CREATE TABLE audit.onboarding_run (
    onboarding_run_id BIGINT IDENTITY PRIMARY KEY,
    client_id UNIQUEIDENTIFIER NOT NULL,
    pipeline_run_id NVARCHAR(100) NULL,
    started_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    completed_at DATETIME2(3) NULL,
    status VARCHAR(30) NOT NULL,
    error_message NVARCHAR(MAX) NULL
);
GO

CREATE INDEX IX_source_client_enabled ON control.source_config(client_id, enabled);
CREATE INDEX IX_ingestion_client_source ON audit.ingestion_run(client_id, source_id, started_at);
CREATE INDEX IX_dq_client_source ON dq.result(client_id, source_id, checked_at);
