# Implementation Details for Phase 6 - ITAR & Export Control

This document tracks the evolution of the ITAR module from the v1.0.0 Prototype to the v1.1.0 Enterprise Data Hub.

---

# [v1.0.0] Initial Prototype Implementation

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

## FR-6.1: Program Management Data Ingestion & Mapping
*For Backend Developers*
- **Description:** Implement high-speed CSV ingestion for project rosters.
- **Acceptance:**
  - [x] Created `ProjectAssignment` SQLAlchemy model.
  - [x] Implemented `ItarService.ingest_roster` with bulk insert logic.
  - [x] Added `POST /api/v1/itar/roster/upload` endpoint.
- **Files:**
  - `backend/src/verity_portal/itar/models.py`
  - `backend/src/verity_portal/itar/service.py`
  - `backend/src/verity_portal/itar/router.py`

## FR-6.2: HR Citizenship Data Standardization
*For Backend Developers*
- **Description:** Automated S3 ingestion and fuzzy-logic normalization of citizenship data.
- **Acceptance:**
  - [x] Updated `Personnel` model with `citizenship_status` ENUM.
  - [x] Created `S3WorkerService` for AWS S3 integration.
  - [x] Implemented fuzzy matching for citizenship normalization.
- **Files:**
  - `backend/src/verity_portal/shared/models.py`
  - `backend/src/verity_portal/itar/s3_worker.py`

---

# [v1.1.0] Enterprise Data Hub Refactor

## Security Foundation: Granular RBAC [MODIFY]
*For Backend Developers*
- **Description:** Migrate from a single `ROLE_EXPORT_CONTROL` to a granular role system.
- **Acceptance:**
  - [x] Update `require_role` to support `ROLE_HR`, `ROLE_PM`, `ROLE_ECO`.
  - [x] Ensure `ROLE_HR` is used for personnel master data.
  - [x] Ensure `ROLE_PM` is used for operational roster uploads.
  - [x] Ensure `ROLE_ECO` is used for project sensitivity and violation resolution.
- **Verify:**
  - [x] Tests verify that `ROLE_PM` cannot upload HR data.

## FR-6.2: Foundational Data Hub (Master Records) [NEW]
*For Backend Developers*
- **Description:** Build the modular SoR (System of Record) gateway.
- **Acceptance:**
  - [x] Create `src/verity_portal/data_hub/core/ingestion.py` with generic bulk-upsert logic.
  - [x] Implement `data_hub/personnel/` with `termination_date` and citizenship normalization.
  - [x] Implement `data_hub/projects/` for master sensitivity classifications.
  - [x] Setup `data_hub/router.py` with type-specific endpoints.
- **Logic Implementation:**
  - [x] Reuse Pandas logic for all SoR streams.
  - [x] Enforce strict ENUMs at the database level for both citizenship and sensitivity.
- **Files:**
  - `backend/src/verity_portal/data_hub/`
- **Verify:**
  - [x] `pytest backend/tests/data_hub/`

## FR-6.1: ITAR Roster Ingestion [MODIFY]
*For Backend Developers*
- **Description:** Refactor ITAR roster ingestion to point to the Data Hub.
- **Acceptance:**
  - [x] Update `ItarService.ingest_roster` to validate against the new `Personnel` model in `data_hub`.
  - [x] Change RBAC on the roster upload endpoint to `ROLE_PM`.
- **Files:**
  - `backend/src/verity_portal/itar/service.py`
  - `backend/src/verity_portal/itar/router.py`

## FR-6.3: ITAR Reconciliation & Auto-Resolution [MODIFY]
*For Backend Developers*
- **Description:** Implement intelligent audit cycles with auto-resolution.
- **Acceptance:**
  - [x] Update `ItarReconciliationEngine` to scan for `SYSTEM_AUTO_RESOLVED` scenarios.
  - [x] Add `resolution_reason` to the violations table for audit trails.
  - [x] Strictly restrict manual resolution to `ROLE_ECO`.
- **Verify:**
  - [x] Seed violation -> Update HR data -> Run Audit -> Verify violation is AUTO_RESOLVED.

## Frontend: Unified Data Hub & Compliance [NEW / MODIFY]
*For Frontend Developers*
- **Description:** Build the role-aware master data dashboard.
- **Acceptance:**
  - [x] Create `DataHubComponent` with conditional tabs for `ROLE_HR` and `ROLE_ECO`.
  - [x] Update `ItarDashboardComponent` to conditionally show "Resolve" based on `ROLE_ECO`.
  - [x] Display auto-resolution reasons in the violations table.
- **Files:**
  - `frontend/src/app/features/data-hub/`
  - `frontend/src/app/features/itar-audit/`
