---
App Version: 1.0.0
---

## Objective
Focus: Domain-Driven Reconciliation and Automated Reporting

## Tech Stack
- **Base Stack:** See [tech_stack.md](tech_stack.md)
- **Module Specific:** `fpdf2` (PDF Generation), `pandas` (Date Parsing)

## Project Structure
- `backend/src/verity_portal/compliance/service.py` → Pure reconciliation logic.
- `backend/src/verity_portal/compliance/exporter.py` → Report generation logic.
- `backend/src/verity_portal/compliance/router.py` → Orchestration endpoints.

## Code Style & Standards
- **Pure Functions:** The `Auditor` service must not have side effects or database dependencies.
- **TDD Requirement:** All audit rules must be verified with unit tests covering multiple edge cases (e.g., active users, same-day terminations).
- **Byte Streams:** Exporters should return bytes or file streams to the API for efficient delivery.

## Boundaries
- **Always do:** Use `pandas.to_datetime` for robust date normalization during ingestion.
- **Never do:** Put PDF styling logic (e.g., cell dimensions) in the API router; encapsulate in the `Exporter` service.
- **Never do:** Hardcode risk thresholds in the logic; use constants or configuration objects.

---

## Requirements

### FR-5.1: Domain Exception Handling
**Architectural Rationale:** Custom domain exceptions prevent "leaking" implementation details (like SQLAlchemy errors) to the API layer, allowing for cleaner error handling in the frontend.

#### 5.1.1. Technical Design Specification
- **Base:** `DomainException` (inherits from `Exception`).
- **Hierarchy:** `MappingError`, `ComplianceException`, `AuditDataInconsistencyError`.

#### 5.1.2. Implementation Details
- [x] Created `domain/exceptions/base.py`.
- [x] Created `domain/exceptions/compliance.py`.

#### 5.1.3. Verification Plan
- [x] **Unit Test:** `pytest tests/domain/test_exceptions.py`

---

### FR-5.2: Date Standardization
**Architectural Rationale:** Normalizing dates to ISO-8601 strings in the database avoids complex timezone or format logic during the reconciliation phase.

#### 5.2.1. Technical Design Specification
- **Parsing:** `pd.to_datetime(value).strftime('%Y-%m-%d')`.

#### 5.2.2. Implementation Details
- [x] Updated `FileManager.confirm_and_ingest` with date detection logic.
- [x] Added unit tests for various international date formats.

#### 5.2.3. Verification Plan
- [x] **Unit Test:** `pytest tests/domain/services/test_file_manager_dates.py`

---

### FR-5.3: Leaver/Mover Audit Logic
**Architectural Rationale:** Implementing the audit as a pure domain function ensures that we can run audits on any data source (e.g., live DB records or uploaded test files) without modification.

#### 5.3.1. Technical Design Specification
- **Logic:** `(hr_list, access_list) -> violation_list`.
- **Complexity:** O(N + M) using dictionary lookups for employee IDs.

#### 5.3.2. Implementation Details
- [x] Implemented `auditor.py`.
- [x] Verified logic with 100% test coverage in `test_auditor.py`.

#### 5.3.3. Verification Plan
- [x] **Unit Test:** `pytest tests/domain/services/test_auditor.py`

---

### FR-5.4: Compliance Reporting & Exports
**Architectural Rationale:** Utilizing `fpdf2` allows for precise control over report layout, ensuring they meet professional auditor standards.

#### 5.4.1. Technical Design Specification
- **PDF:** Custom `FPDF` class in `exporter.py`.
- **CSV:** Standard library `csv` module for maximum compatibility.

#### 5.4.2. Implementation Details
- [x] Implemented `generate_audit_pdf` and `generate_audit_csv`.
- [x] Wired up API endpoints to return `StreamingResponse` for downloads.
- [x] Built the `AuditDashboardComponent` in Angular to handle triggers and downloads.

#### 5.4.3. Verification Plan
- [x] **Manual Check:** Verify PDF and CSV download functionality in the dashboard.
