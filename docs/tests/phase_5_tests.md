# Phase 5: Test-Driven Development Spec

## 1. Unit Tests for Date Parsing (Mapping Phase)
**Location**: `backend/tests/domain/services/test_file_manager.py` (or new test file for mapping dates)

- `test_confirm_and_ingest_parses_dates()`:
  - **Arrange:** Provide CSV content with a date column (`12/31/2023`).
  - **Act:** Call `confirm_and_ingest` with mapping indicating that column is a date.
  - **Assert:** The database `IntakeRecordModel.data` contains the date formatted as ISO-8601 (`2023-12-31`).

## 2. Unit Tests for Domain Logic (Auditor)
**Location**: `backend/tests/domain/services/test_auditor.py`

These tests verify the core business rules of the Leaver/Mover audit. The domain logic must remain isolated from FastAPI and SQLAlchemy.

### Scenarios:

- `test_audit_leaver_mover_identifies_violation()`:
  - **Arrange:** Provide an HR record with `hr_termination_date = "2023-10-01"` and an Access record for the same `employee_id` with `last_system_login = "2023-10-05"`.
  - **Act:** Call `audit_leaver_mover(hr_records, access_records)`.
  - **Assert:** The resulting violation list contains exactly one entry for that employee.

- `test_audit_leaver_mover_ignores_valid_access()`:
  - **Arrange:** Provide an HR record with `hr_termination_date = "2023-10-10"` and an Access record with `last_system_login = "2023-10-05"`.
  - **Act:** Call `audit_leaver_mover(hr_records, access_records)`.
  - **Assert:** The violation list is empty (login occurred before termination).

- `test_audit_leaver_mover_handles_active_employees()`:
  - **Arrange:** Provide an HR record with no termination date (active employee) and a recent Access record.
  - **Act:** Call `audit_leaver_mover`.
  - **Assert:** The violation list is empty.

## 3. Unit Tests for Exporter Service
**Location**: `backend/tests/domain/services/test_exporter.py`

- `test_generate_csv_export()`:
  - **Arrange:** Provide a list of violation dictionaries.
  - **Act:** Call `generate_audit_csv(violations)`.
  - **Assert:** Returns a valid CSV string/bytes containing the correct headers and row data.
- `test_generate_pdf_export()`:
  - **Arrange:** Provide a list of violation dictionaries.
  - **Act:** Call `generate_audit_pdf(violations)`.
  - **Assert:** Returns a byte string starting with the standard PDF header (`%PDF-`).

## 4. Integration Tests for Audit & Export Endpoints
**Location**: `backend/tests/infrastructure/api/test_audit.py`

### Scenarios:

- `test_run_leaver_mover_audit_success()`:
  - **Arrange:** Seed the database with Intake records.
  - **Act:** `POST /audit/leaver-mover` with `{ hr_job_id: "...", access_job_id: "..." }`.
  - **Assert:** Returns `200 OK`. The JSON response contains a `violations` array.
- `test_export_audit_results_csv()`:
  - **Arrange:** Mock/run the audit to get results.
  - **Act:** `POST /audit/export/csv` with the violation payload.
  - **Assert:** Returns `200 OK` with `Content-Type: text/csv`.
- `test_export_audit_results_pdf()`:
  - **Arrange:** Mock/run the audit to get results.
  - **Act:** `POST /audit/export/pdf` with the violation payload.
  - **Assert:** Returns `200 OK` with `Content-Type: application/pdf`.

## 5. Frontend Component Tests
**Location**: `frontend/src/app/features/audit/audit-dashboard.component.spec.ts`

- `test_audit_dashboard_renders_violations()`:
  - **Arrange:** Mock the `HttpClient` to return violations.
  - **Act:** Trigger the audit button. Run change detection.
  - **Assert:** The data table renders the violation rows.
- `test_audit_dashboard_triggers_export()`:
  - **Arrange:** Mock the `HttpClient` for the export endpoints.
  - **Act:** Click the "Export PDF" button.
  - **Assert:** The component initiates a file download with the blob response.
