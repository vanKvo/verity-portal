# ADR-006: Hybrid Data Ingestion Strategy (Manual UI & S3 Simulation)

## Status
Accepted

## Context & Problem Statement
The primary business value of the Verity Portal is solving the "Excel Engineering" problem—reconciling disparate data sources from siloed enterprise systems (e.g., HR vs. Program Management, Procurement vs. IT Helpdesk). 

In a real-world enterprise, the primary user of a compliance module (e.g., an Export Control Officer or an IT Security Admin) rarely has direct API access or login credentials to the secondary system (e.g., the corporate HR Workday instance or the Finance SAP instance).

Because this is a portfolio project without access to live enterprise APIs, we must decide how to realistically simulate this cross-departmental data ingestion.

## Decision
We will adopt a **Hybrid Data Ingestion Architecture** that utilizes both event-driven cloud ingestion and manual UI uploads.

Depending on the module's real-world access boundaries, data will be ingested via one of two patterns:

### 1. Pattern A: The "Semi-Automated" Flow (S3 + UI)
**Used For:** Modules where the primary user does *not* have access to the secondary data source (e.g., ITAR Export Control, Leaver/Mover Audit, IT Asset Audit).
*   **The S3 Simulation:** We will simulate the locked-down department (e.g., HR) by configuring a secure AWS S3 bucket. We will assume an external, automated script from the HR system drops a daily CSV export into this bucket.
*   **The Backend Integration:** The Verity Portal FastAPI backend will use `boto3` (and either cron jobs or S3 event triggers) to automatically ingest and parse this S3 data without any user interaction.
*   **The UI Component:** The primary user logs into the portal and uses the drag-and-drop UI to manually upload their portion of the data (e.g., Active Directory logs or Project Rosters).
*   **The Reconciliation:** The engine instantly cross-references the manual UI upload against the already-ingested S3 data.

### 2. Pattern B: The "Dual Manual Upload" Flow (UI + UI)
**Used For:** Modules where the primary user realistically has access to both systems (e.g., Clearance Watchdog, Labor Billing Audit).
*   The user utilizes the Intake UI to upload both files manually.

## Rationale
*   **Decoupled Architecture:** Implementing an S3-based ingestion pipeline establishes an Event-Driven Architecture, preventing tight coupling between the portal and external legacy systems.
*   **Security & Compliance:** Background ingestion via S3 eliminates the need to email sensitive PII or grant external systems direct access to the portal's database.
*   **Matches Enterprise Reality:** It perfectly mirrors how enterprises bridge legacy systems securely when direct API integrations are prohibited or technically infeasible. "HR drops a flat file in S3 overnight" is an industry-standard, secure workaround.

## Consequences
*   **Positive:** Eliminates manual data entry for locked-down systems, reducing human error and fulfilling the core business requirement of automated compliance.
*   **Negative:** Increases backend complexity. Requires provisioning AWS S3 buckets (or local MinIO for development), configuring `boto3`, and managing background tasks (e.g., Celery or FastAPI `BackgroundTasks`) to handle the automated ingestion gracefully without blocking the main event loop.
*   **Negative:** Requires robust asynchronous error handling (e.g., if the S3 file is malformed, the system must trigger an email/dashboard alert since there is no user waiting at a UI screen to see the error).
