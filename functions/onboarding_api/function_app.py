import json
import logging
import os
import uuid

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.mgmt.storage import StorageManagementClient
from azure.storage.filedatalake import DataLakeServiceClient
import pyodbc

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

credential = DefaultAzureCredential()

def get_sql_connection():
    # In production use an Azure SQL Entra/managed-identity connection.
    server = os.environ["SQL_SERVER"]
    database = os.environ["SQL_DATABASE"]
    conn_str = (
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        "Encrypt=yes;TrustServerCertificate=no;"
        "Authentication=ActiveDirectoryMsi;"
    )
    return pyodbc.connect(conn_str)

def provision_client_container(client_id: str):
    account = os.environ["STORAGE_ACCOUNT"]
    container = f"client-{client_id}".lower()

    service = DataLakeServiceClient(
        account_url=f"https://{account}.dfs.core.windows.net",
        credential=credential,
    )
    fs = service.get_file_system_client(container)
    try:
        fs.create_file_system()
    except Exception:
        # Idempotent: container may already exist.
        logging.info("Container already exists or was created concurrently.")

    for path in ("raw", "quarantine", "curated"):
        try:
            fs.get_directory_client(path).create_directory()
        except Exception:
            pass

@app.route(route="onboard", methods=["POST"])
def onboard(req: func.HttpRequest) -> func.HttpResponse:
    try:
        body = req.get_json()
        client_name = body["client_name"].strip()
        client_id = body.get("client_id") or str(uuid.uuid4())

        if not client_name:
            return func.HttpResponse("client_name is required", status_code=400)

        provision_client_container(client_id)

        with get_sql_connection() as conn:
            cur = conn.cursor()
            cur.execute(
                "EXEC onboarding.usp_register_client ?, ?",
                client_id,
                client_name,
            )
            conn.commit()

        # Trigger ADF from a separate API/automation layer in production.
        # Keeping orchestration outside this handler makes retries safer.
        response = {
            "client_id": client_id,
            "status": "REGISTERED",
            "message": "Client registered and storage artifacts provisioned."
        }
        return func.HttpResponse(
            json.dumps(response),
            mimetype="application/json",
            status_code=202,
        )

    except Exception as exc:
        logging.exception("Onboarding failed")
        return func.HttpResponse(
            json.dumps({"error": str(exc)}),
            mimetype="application/json",
            status_code=500,
        )
