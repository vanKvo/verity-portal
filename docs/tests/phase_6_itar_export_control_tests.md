# Phase 6: ITAR & Export Control - Test Specification
---
App Version: 1.1.0
---

## Document History / Changelog
> [!WARNING]
> **ATTENTION DEVELOPERS:** Version 1.1.0 introduces significant architectural changes. Tests marked with **[NEW]** or **[MODIFY]** must be written/updated before implementing the corresponding feature code (TDD). Tests marked with **[DELETE]** should be removed as the underlying architecture has been deprecated.

## Objective
To ensure strict ITAR compliance by verifying the accurate ingestion of project rosters, the automated event-driven ingestion of HR citizenship data from S3, and the flawless execution of the Reconciliation Engine to detect export control violations.

---

## Incremental Test Plan

### FR-6.1: Manual Roster Ingestion
*Ensures that Program Management data can be uploaded and mapped to personnel correctly via the UI.*

**Test 1: Successful Roster Upload (Backend)** **[MODIFY]**
- **Purpose:** Verify valid CSVs create database relationships.
- **Test name:** `test_ingest_roster_success` 
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Seed database with Personnel ID '101' and Project ID '500' (via new `PersonnelService`). Mock an uploaded CSV containing these IDs. Authenticate with `ROLE_PM`. *(Modified: Now requires ROLE_PM instead of ROLE_EXPORT_CONTROL)*
- **Action:** Call the upload endpoint.
- **Assertion 1:** HTTP status is 200 OK.
- **Assertion 2:** `project_assignments` table contains the link between 101 and 500.

**Test 1.1: RBAC Enforcement (Backend)** **[MODIFY]**
- **Purpose:** Ensure the endpoint rejects requests without the `ROLE_PM` role.
- **Test name:** `test_ingest_roster_unauthorized`
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Generate a mock JWT that lacks the `ROLE_PM` claim.
- **Action:** Call the upload endpoint with the mock token.
- **Assertion 1:** HTTP status is 403 Forbidden.

**Test 2: Unrecognized Employee Handling (Backend)**
- **Purpose:** Ensure system does not crash on bad data but safely flags it.
- **Test name:** `test_ingest_roster_invalid_employee` 
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Mock an uploaded CSV containing an Employee ID that does not exist in the DB.
- **Action:** Call the upload endpoint.
- **Assertion 1:** System raises an `ITARMappingError`.
- **Assertion 2:** Valid rows are inserted; invalid rows are returned in an error response object.

**Test 3: File Upload UI Rendering (Frontend)**
- **Purpose:** Verify the user can interact with the upload workflow.
- **Test name:** `should display upload success or mapping error table` 
- **Target Component:** `RosterUploadViewComponent` (`src/app/itar/roster-upload.component.ts`)
- **Setup:** Mock the Angular `ItarService` to return a `MappingError` response.
- **Action:** Trigger the file upload submit button.
- **Assertion 1:** The error `MatTable` renders showing the specific rows that failed.

---

### FR-6.2: Master Data Hub (HR & Project Ingestion)
*Ensures foundational data is correctly ingested via webhooks, dynamic routing, and manual overrides.*

**Test 4: S3 Webhook Trigger & Dynamic Routing (Backend)** **[NEW]**
- **Purpose:** Verify the webhook endpoint securely receives S3 payloads, schedules background ingestion, and routes dynamically based on object key keywords.
- **Target Route:** `POST /data-hub/webhooks/s3-ingest` (`src/verity_portal/data_hub/router.py`)
- **Setup:** 
  1. Mock S3 event payload with file key `"hr/hr_personnel_records_v5.numbers"`.
  2. Mock S3 event payload with file key `"projects/project_governance.csv"`.
  3. Mock S3 event payload with file key `"inventory/stock_list.xlsx"`.
- **Action:** POST each payload to the webhook endpoint.
- **Assertion 1 (HR Key):** Endpoint returns 200 OK with `message: "S3 Sync Triggered"`, queues background ingestion, and routes to `PersonnelService.ingest_master_data`.
- **Assertion 2 (Project Key):** Endpoint returns 200 OK, queues background ingestion, and routes to `ProjectService.ingest_master_data`.
- **Assertion 3 (Invalid Key):** Endpoint raises `IngestionRoutingError` or returns 400 Bad Request since the key did not contain `"hr"`, `"personnel"`, or `"project"`.

**Test 5: Manual Override RBAC enforcement (Backend)** **[NEW]**
- **Purpose:** Ensure role-based boundaries prevent unauthorized spreadsheet manual uploads.
- **Target Route 1:** `POST /data-hub/personnel/upload`
- **Target Route 2:** `POST /data-hub/projects/upload`
- **Setup:** 
  1. Authenticate a user with `ROLE_PM`.
  2. Authenticate a user with `ROLE_HR`.
  3. Authenticate a user with `ROLE_ECO`.
- **Action:** Trigger file upload to each manual endpoint.
- **Assertion 1 (HR endpoint):** `ROLE_PM` receives 403 Forbidden; `ROLE_HR` receives 200 OK.
- **Assertion 2 (Project endpoint):** `ROLE_PM` receives 403 Forbidden; `ROLE_ECO` receives 200 OK.

**Test 6: Thread-Safe .numbers Temporary File Parsing (Backend)** **[NEW]**
- **Purpose:** Verify seekable binary stream extraction for `.numbers` format works correctly in a multi-threaded context and cleanly deletes the buffer.
- **Target Service:** `file_utils.parse_file_to_df` (`src/verity_portal/core/utils/file_utils.py`)
- **Setup:** Mock a binary `BytesIO` payload of a valid Numbers spreadsheet.
- **Action:** Execute the parser function.
- **Assertion 1:** The function writes to a temporary file buffer on disk to bypass `zipfile` limitations.
- **Assertion 2:** The file is parsed successfully and returned as a standard Pandas DataFrame.
- **Assertion 3:** The temporary file on disk is strictly deleted from `/tmp` or the workspace cache post-execution.

**Test 7: Dynamic Column Header Mapping (Backend)** **[NEW]**
- **Purpose:** Ensure that submitting custom JSON mapping dictionary parses raw columns to standard DB models.
- **Target Route:** `POST /data-hub/personnel/upload`
- **Setup:** Upload a file with custom headers "Work Email" and "National Status" along with mapping `{"Work Email": "email", "National Status": "citizenship_status"}`.
- **Action:** Execute the upload.
- **Assertion 1:** The engine parses and normalizes the values, saving them to correct DB fields.
- **Assertion 2:** Variations such as "U.S. Citizen" map correctly to the standard `US_CITIZEN` ENUM.

---

### FR-6.3: ITAR Reconciliation Engine
*Ensures the core compliance engine correctly identifies restricted access mismatches and enforces Separation of Duties.*

**Test 8: Safe Access Scenario (Backend)**
- **Purpose:** Ensure the engine does not generate false positives.
- **Test name:** `test_reconciliation_engine_safe_access` 
- **Target Service:** `ItarReconciliationEngine` (`src/verity_portal/itar/service.py`)
- **Setup:** Seed DB with a `US_CITIZEN` assigned to an `ITAR_RESTRICTED` project.
- **Action:** Execute `run_audit()`.
- **Assertion 1:** No violations are created in the `compliance_violations` table.

**Test 9: Violation Detection Scenario (Backend)**
- **Purpose:** Ensure the engine flags illegal assignments immediately.
- **Test name:** `test_reconciliation_engine_violation_detected` 
- **Target Service:** `ItarReconciliationEngine` (`src/verity_portal/itar/service.py`)
- **Setup:** Seed DB with a `FOREIGN_NATIONAL` assigned to an `ITAR_RESTRICTED` project.
- **Action:** Execute `run_audit()`.
- **Assertion 1:** A high-priority record is inserted into `compliance_violations`.

**Test 10: System Auto-Resolution (Backend)** **[NEW]**
- **Purpose:** Verify that updated Master Data automatically resolves stale ITAR violations without deleting the historical record.
- **Target Service:** `ItarReconciliationEngine.run_audit()`
- **Setup:** 
  1. Seed DB with `OPEN` violation for Employee A (Foreign National).
  2. Modify Employee A in `personnel` DB to `US_CITIZEN` (simulating an HR Master Data update).
- **Action:** Execute `run_audit()`.
- **Assertion 1:** The `OPEN` violation transitions to `RESOLVED`.
- **Assertion 2:** The resolution reason is strictly set to `SYSTEM_AUTO_RESOLVED`.

**Test 11: Violations Dashboard Rendering (Frontend)**
- **Purpose:** Verify the Export Control Officer can view actionable alerts.
- **Test name:** `should fetch and display active compliance violations` 
- **Target Component:** `ViolationsDashboardComponent` (`src/app/itar/dashboard.component.ts`)
- **Setup:** Mock the API to return one OPEN violation.
- **Action:** Initialize the component.
- **Assertion 1:** The `MatTable` renders one row containing the employee's name, project, and date detected.

**Test 12: ECO Resolution Enforcement (Frontend)** **[MODIFY]**
- **Purpose:** Verify Program Managers cannot dismiss compliance alerts.
- **Target Component:** `ViolationsDashboardComponent`
- **Setup 1:** Render component with mock user having `ROLE_PM`.
- **Assertion 1:** The "Resolve Violation" button is NOT present in the DOM.
- **Setup 2:** Render component with mock user having `ROLE_ECO`.
- **Assertion 2:** The "Resolve Violation" button IS present and active.
