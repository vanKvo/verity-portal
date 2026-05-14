# Implementation Details for Phase 6 - ITAR & Export Control

## Security Foundation: Stubbed RBAC
*For Backend Developers*
- **Description:** Implement a role-based access control (RBAC) contract to secure compliance endpoints.
- **Acceptance:**
  - [x] Implemented `require_role` FastAPI dependency.
  - [x] Migrated identity module to plural `roles` list format.
  - [x] Injected `ROLE_EXPORT_CONTROL` into the Guest Login for local testing.
- **Logic Implementation:**
  - Created `require_role` dependency in `src/verity_portal/core/security/roles.py`.
  - Updated `User` model and schemas to support a list of roles.
- **Files:**
  - `backend/src/verity_portal/core/security/roles.py`
  - `backend/src/verity_portal/identity/models.py`
  - `backend/src/verity_portal/identity/schemas.py`
- **Verify:**
  - Attempting to access ITAR endpoints with a guest user (who now has the role) succeeds.

---

## FR-6.1: Program Management Data Ingestion & Mapping
*For Backend Developers*
- **Description:** Implement high-speed CSV ingestion for project rosters.
- **Acceptance:**
  - [x] Created `ProjectAssignment` SQLAlchemy model.
  - [x] Implemented `ItarService.ingest_roster` with bulk insert logic.
  - [x] Added `POST /api/v1/itar/roster/upload` endpoint.
- **Logic Implementation:**
  - Used `pandas` for high-performance CSV parsing.
  - Implemented validation for required columns (`employee_id`, `project_id`).
  - Optimized database insertion by checking for existing assignments before creating new ones.
- **Files:**
  - `backend/src/verity_portal/itar/models.py`
  - `backend/src/verity_portal/itar/service.py`
  - `backend/src/verity_portal/itar/router.py`
- **Verify:**
  - `poetry run pytest backend/tests/itar/test_roster_ingestion.py`

*For Frontend Developers*
- **Description:** Build the ITAR Dashboard and roster upload interface.
- **Acceptance:**
  - [x] Created `ItarDashboardComponent` with Material Design.
  - [x] Implemented file upload service and snackbar feedback.
- **Logic Implementation:**
  - Built a clean, responsive dashboard using Angular Material.
  - Implemented `ItarService.uploadRoster` to handle multi-part file uploads.
- **Files:**
  - `frontend/src/app/features/itar-audit/components/itar-dashboard.component.ts`
  - `frontend/src/app/features/itar-audit/services/itar.service.ts`
- **Verify:**
  - Manual verification of file upload via UI with success snackbar notification.

---

## FR-6.2: HR Citizenship Data Standardization
*For Backend Developers*
- **Description:** Automated S3 ingestion and fuzzy-logic normalization of citizenship data.
- **Acceptance:**
  - [x] Updated `Personnel` model with `citizenship_status` ENUM.
  - [x] Created `S3WorkerService` for AWS S3 integration.
  - [x] Implemented fuzzy matching for citizenship normalization.
- **Logic Implementation:**
  - Used `boto3` for S3 interactions and `moto` for local testing.
  - Leveraged `thefuzz` library to map raw strings (e.g., "USA", "United States") to strict `CitizenshipStatus` values.
- **Files:**
  - `backend/src/verity_portal/shared/models.py`
  - `backend/src/verity_portal/itar/s3_worker.py`
  - `backend/src/verity_portal/core/config.py`
- **Verify:**
  - `poetry run pytest backend/tests/itar/test_s3_sync.py`

---

## FR-6.3: Automated ITAR Reconciliation Engine
*For Backend Developers*
- **Description:** Core reconciliation engine to detect ITAR compliance violations.
- **Acceptance:**
  - [x] Implemented `ItarService.run_reconciliation_audit`.
  - [x] Created violations retrieval and resolution endpoints.
- **Logic Implementation:**
  - Developed a high-performance join query between `Assignments`, `Personnel`, and `Projects`.
  - Automatically flags `FOREIGN_NATIONAL` users on `ITAR_RESTRICTED` projects.
- **Files:**
  - `backend/src/verity_portal/itar/service.py`
  - `backend/src/verity_portal/itar/router.py`
  - `backend/src/verity_portal/itar/models.py`
- **Verify:**
  - `poetry run pytest backend/tests/itar/test_reconciliation.py`

*For Frontend Developers*
- **Description:** Compliance audit monitoring and remediation UI.
- **Acceptance:**
  - [x] Integrated violations table into the dashboard.
  - [x] Implemented "Resolve Violation" action logic.
- **Logic Implementation:**
  - Used `MatTable` with real-time data from the `ItarService`.
  - Added action buttons to remediate violations directly from the dashboard.
- **Files:**
  - `frontend/src/app/features/itar-audit/components/itar-dashboard.component.ts`
  - `frontend/src/app/features/itar-audit/services/itar.service.ts`
- **Verify:**
  - Violation engine detects mismatches and displays them in the UI; clicking "Resolve" updates the status in the DB.
