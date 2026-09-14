CREATE OR ALTER PROCEDURE onboarding.usp_register_client
    @client_id UNIQUEIDENTIFIER,
    @client_name NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM onboarding.client WHERE client_id = @client_id)
    BEGIN
        UPDATE onboarding.client
        SET client_name = @client_name,
            updated_at = SYSUTCDATETIME()
        WHERE client_id = @client_id;
    END
    ELSE
    BEGIN
        INSERT INTO onboarding.client(client_id, client_name)
        VALUES (@client_id, @client_name);
    END

    SELECT client_id, client_name, status
    FROM onboarding.client
    WHERE client_id = @client_id;
END;
GO

CREATE OR ALTER PROCEDURE control.usp_get_sources
    @client_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT source_id, source_name, source_type, linked_service_name,
           function_route, schema_name, table_name, business_key,
           watermark_column, watermark_type, current_watermark
    FROM control.source_config
    WHERE client_id = @client_id
      AND enabled = 1
    ORDER BY source_id;
END;
GO

CREATE OR ALTER PROCEDURE control.usp_get_watermark
    @source_id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT current_watermark
    FROM control.source_config
    WHERE source_id = @source_id;
END;
GO

CREATE OR ALTER PROCEDURE control.usp_advance_watermark
    @source_id BIGINT,
    @new_watermark NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE control.source_config
    SET current_watermark = @new_watermark,
        updated_at = SYSUTCDATETIME()
    WHERE source_id = @source_id
      AND (
          current_watermark IS NULL
          OR @new_watermark > current_watermark
      );
END;
GO

CREATE OR ALTER PROCEDURE audit.usp_start_ingestion
    @client_id UNIQUEIDENTIFIER,
    @source_id BIGINT,
    @pipeline_run_id NVARCHAR(100),
    @old_watermark NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit.ingestion_run
        (client_id, source_id, pipeline_run_id, status, old_watermark)
    VALUES
        (@client_id, @source_id, @pipeline_run_id, 'RUNNING', @old_watermark);

    SELECT CAST(SCOPE_IDENTITY() AS BIGINT) AS ingestion_run_id;
END;
GO

CREATE OR ALTER PROCEDURE audit.usp_complete_ingestion
    @ingestion_run_id BIGINT,
    @status VARCHAR(30),
    @rows_read BIGINT = NULL,
    @rows_written BIGINT = NULL,
    @new_watermark NVARCHAR(200) = NULL,
    @error_message NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE audit.ingestion_run
    SET status = @status,
        rows_read = @rows_read,
        rows_written = @rows_written,
        new_watermark = @new_watermark,
        error_message = @error_message,
        completed_at = SYSUTCDATETIME()
    WHERE ingestion_run_id = @ingestion_run_id;
END;
GO
