# Implementation Log - Verity Portal

## Phase 1: Foundation

### Task 1.1: Initialize Backend Project
- **Description:** Set up the FastAPI backend with Poetry and Hexagonal folder structure.
- **Acceptance:**
  - [x] Poetry initialized with dependencies (FastAPI, SQLAlchemy, etc.)
  - [x] Hexagonal folder structure created.
  - [x] `main.py` and `config.py` implemented.
- **Key Logic Implementation:**
  - Used `pydantic-settings` for environment variable management.
  - Implemented Hexagonal structure: `domain/` (core logic), `infrastructure/` (adapters and API).
  - Configured CORS and health check endpoint.
- **Files:**
  - `backend/pyproject.toml`
  - `backend/app/main.py`
  - `backend/app/config.py`
  - `backend/app/domain/`
  - `backend/app/infrastructure/`
- **Verify:**
  - `poetry run pytest` passes with a health check test.

### Task 1.2: Initialize Database & Migrations
- **Description:** Set up PostgreSQL with Docker and Alembic for migrations.
- **Acceptance:**
  - [x] `docker-compose.yml` for PostgreSQL 16.
  - [x] Alembic initialized and configured to use app settings.
  - [x] Initial migration created and applied.
- **Key Logic Implementation:**
  - Configured Alembic's `env.py` to dynamically load `DATABASE_URL` from the application's Pydantic settings.
  - Fixed Pydantic list parsing issue for `ALLOWED_DOMAINS` using a comma-separated string adapter.
- **Files:**
  - `docker-compose.yml`
  - `backend/alembic/`
  - `backend/alembic.ini`
  - `backend/app/infrastructure/adapters/database/setup.py`
- **Verify:**
  - Database is up and running in Docker.
  - `alembic upgrade head` successfully applied the initial migration.

### Task 1.3: Initialize Frontend Project
- **Description:** Create Angular 21 project with Standalone components, Angular Material, and Jest.
- **Acceptance:**
  - [x] Angular 21 project initialized.
  - [x] Standalone components and routing configured.
  - [x] Angular Material installed.
  - [x] Jest configured for unit testing (replacing Karma).
  - [x] Folder structure set up (`core/`, `shared/`, `features/`).
- **Key Logic Implementation:**
  - Replaced Karma/Jasmine with Jest using `jest-preset-angular` v16 (supporting Angular 21).
  - Configured `setup-jest.ts` to use `setupZoneTestEnv()` for proper test environment initialization.
  - Organized folders to follow Angular best practices for large-scale applications.
- **Files:**
  - `frontend/package.json`
  - `frontend/jest.config.js`
  - `frontend/src/app/core/`
  - `frontend/src/app/shared/`
  - `frontend/src/app/features/`
- **Verify:**
  - `npm test` runs successfully using Jest.
  - `npm start` (verified via build/test success).

## Phase 1 Checkpoint: Foundation
 - Backend server runs (poetry run uvicorn app.main:app --reload)
 - Frontend server runs (npm start)
 - Database is reachable and migrations apply cleanly.

## Phase 2: Auth Module & Guest Login

### Task 2.1: Backend Auth Domain & Database
- **Description:** Implement User domain model with secure Bcrypt password hashing and corresponding SQLAlchemy adapter.
- **Acceptance:**
  - [x] User model created in domain layer.
  - [x] Passwords hashed securely using Bcrypt.
  - [x] SQLAlchemy `UserModel` created for PostgreSQL.
- **Key Logic Implementation:**
  - Applied Hexagonal architecture by separating `domain/models/user.py` from `infrastructure/adapters/database/models.py`.
  - Implemented TDD: Auth domain tests drive the `passlib` Bcrypt implementation and domain validation logic (corporate email domain restriction).
  - Configured `StaticPool` in testing `sessionmaker` to enable SQLite in-memory tests across multiple test fixtures without operational errors.
- **Files:**
  - `backend/app/domain/models/user.py`
  - `backend/app/infrastructure/adapters/database/models.py`
  - `backend/tests/domain/test_user.py`
  - `backend/tests/infrastructure/adapters/test_database_models.py`
- **Verify:**
  - `poetry run pytest tests/domain/test_user.py` passes.
  - `poetry run pytest tests/infrastructure/adapters/test_database_models.py` passes.

### Task 2.2: Backend Auth Endpoints
- **Description:** Expose REST endpoints for user registration, standard JWT login, and a frictionless guest login.
- **Acceptance:**
  - [x] `/auth/register` endpoint validates domain and persists user.
  - [x] `/auth/login` endpoint validates credentials and returns JWT.
  - [x] `/auth/guest-login` endpoint issues a role-based JWT without credentials.
- **Key Logic Implementation:**
  - Developed with strict TDD, first writing 5 integration tests using FastAPI `TestClient`.
  - Isolated database queries using `Depends(get_db)` and overrode this dependency in `test_auth.py` to use an isolated in-memory SQLite schema.
  - Leveraged `PyJWT` for stateless authentication tokens (`access_token`) injected with custom roles (`user` or `guest`).
  - Implemented `ADR-001` decision to use JWTs and a Guest bypass.
- **Files:**
  - `backend/app/infrastructure/api/routes/auth.py`
  - `backend/app/infrastructure/api/schemas/auth.py`
  - `backend/tests/infrastructure/api/test_auth.py`
  - `docs/decisions/ADR-001-authentication-strategy.md`
- **Verify:**
  - `poetry run pytest tests/infrastructure/api/test_auth.py` passes 100% of integration tests.

### Task 2.3: Frontend Auth Module
- **Description:** Implement the Angular Auth module, including a premium login interface, guest access, and route protection.
- **Acceptance:**
  - [x] `AuthService` implemented using Angular Signals for state management.
  - [x] Premium Login UI created with Angular Material.
  - [x] "One-Click Guest Login" functionality implemented for recruiters.
  - [x] `AuthGuard` and `GuestGuard` implemented to secure routes.
  - [x] Unauthenticated users are automatically redirected to the login page.
- **Key Logic Implementation:**
  - Used **Angular Signals** (`signal`, `computed`) in `AuthService` to provide a reactive, globally accessible authentication state.
  - Implemented **Standalone Components** for `LoginComponent` and `DashboardComponent`, following Angular 21 best practices.
  - Integrated **Reactive Forms** for the login interface with real-time validation for corporate email domains.
  - Applied the **BAE Navy palette** via custom CSS and Angular Material components to ensure a premium, enterprise-grade feel.
  - Used `localStorage` for stateless JWT persistence across browser sessions.
- **Files:**
  - `frontend/src/app/core/services/auth.service.ts`
  - `frontend/src/app/core/guards/auth.guard.ts`
  - `frontend/src/app/features/auth/login/`
  - `frontend/src/app/app.routes.ts`
- **Verify:**
  - `npm test` passes.
  - Manual verification of routing logic (Login -> Dashboard on success).

## Phase 2 Checkpoint: Auth
 - [x] User can log in with valid credentials.
 - [x] Recruiter can bypass login using "Guest Login".
 - [x] Unauthenticated users are redirected to the login page.

## Phase 3: File Management Service

### Task 3.1: Storage Infrastructure (Port & Local Adapter)
- **Description:** Define the `StoragePort` interface and implement a `LocalFileSystemAdapter` for staging and archival.
- **Acceptance:**
  - [x] `StoragePort` interface defined in the domain layer.
  - [x] `LocalFileSystemAdapter` implemented for local disk storage.
  - [x] Supports `save`, `get`, `delete`, and `move` operations.
- **Key Logic Implementation:**
  - Used `aiofiles` for asynchronous file I/O to ensure the FastAPI server remains responsive during large file operations.
  - Implemented automatic directory management (creating `/staging` and `/archive` if they don't exist).
  - Used UUID-based safe filenames to prevent collisions and directory traversal attacks.
- **Files:**
  - `backend/app/domain/ports/storage_port.py`
  - `backend/app/infrastructure/adapters/storage/local_adapter.py`
- **Verify:**
  - `poetry run pytest tests/infrastructure/adapters/storage/test_local_adapter.py` passes.

### Task 3.2: Database Schema for File Metadata
- **Description:** Define the `FileMetadataModel` and apply migrations to track file lifecycle within the `verity` schema.
- **Acceptance:**
  - [x] `FileMetadataModel` added to SQLAlchemy adapters with `schema="verity"`.
  - [x] `UserModel` updated to use `schema="verity"` for consistency with the user's database design.
  - [x] Alembic `env.py` fixed to import models and include schema detection.
  - [x] Alembic migration generated and applied.
- **Key Logic Implementation:**
  - Configured `__table_args__ = {"schema": "verity"}` in all SQLAlchemy models to align with the enterprise schema defined in `schema_v1.sql`.
  - Fixed `alembic/env.py` by importing `FileMetadataModel` and `UserModel` to enable autogenerate detection.
  - Enabled `include_schemas=True` in `context.configure` to allow Alembic to manage tables outside the default `public` schema.
  - Manually added `op.execute('CREATE SCHEMA IF NOT EXISTS verity')` to the migration script for robustness.
- **Files:**
  - `backend/app/infrastructure/adapters/database/models.py`
  - `backend/alembic/env.py`
  - `backend/alembic/versions/fa38a300acde_add_file_metadata_table.py`
- **Verify:**
  - `alembic upgrade head` applied successfully.
  - `docker exec verity-db psql -U user -d verity_db -c "\dt verity.*"` confirms `verity.file_metadata` and `verity.users` exist.

### Task 3: File Manager Service (Domain Orchestration)
- **Description:** Implement the `FileManager` domain service to coordinate storage and database updates.
- **Acceptance:**
  - [x] `FileManager` service implemented in the domain layer.
  - [x] Supports `ingest_file` with 50MB size validation.
  - [x] Supports `archive_file` coordinating physical move and metadata updates.
- **Key Logic Implementation:**
  - Implemented strict 50MB limit validation in the domain layer to prevent oversized uploads.
  - Coordinated the vertical slice: saving the physical file first, then recording the metadata to ensure consistency.
  - Developed using TDD: wrote RED tests for the service logic (mocking the port and database) before implementation.
- **Files:**
  - `backend/app/domain/services/file_manager.py`
  - `backend/tests/domain/services/test_file_manager.py`
- **Verify:**
  - `poetry run pytest tests/domain/services/test_file_manager.py` passes 100%.

## Phase 3 Checkpoint: File Management
 - [x] Files up to 50MB can be ingested into a temporary `/staging` directory.
 - [x] File metadata is tracked in PostgreSQL for every upload.
 - [x] Files can be moved to `/archive` and metadata status updated accordingly.

## Phase 4: Shared Mapper Service

### Task 4.1: Fuzzy Mapping Logic
- **Description:** Implement fuzzy logic using `thefuzz` to suggest mappings between input headers and a target schema.
- **Acceptance:**
  - [x] Exact matches return 100% confidence.
  - [x] Fuzzy matches (e.g., "FName" -> "first_name") return > 70% confidence.
  - [x] Normalization (lowercase, removal of underscores/spaces) improves matching accuracy.
- **Key Logic Implementation:**
  - Used `fuzz.ratio` for strict string comparison, which proved more accurate for short header names than `WRatio`.
  - Implemented a normalization layer that strips special characters and spaces before matching.
  - Developed using TDD: RED unit tests in `test_mapper.py` were made GREEN by the implementation.
- **Files:**
  - `backend/app/domain/services/mapper.py`
  - `backend/tests/domain/services/test_mapper.py`
- **Verify:**
  - `poetry run pytest tests/domain/services/test_mapper.py` passes 100%.

### Task 4.2: Data Intake API & Ingestion
- **Description:** Create endpoints for file upload (with header extraction) and confirmed mapping ingestion.
- **Acceptance:**
  - [x] `/intake/upload` accepts CSV/XLSX and returns headers + suggestions.
  - [x] `/intake/confirm/{job_id}` persists mapped data into PostgreSQL as JSONB.
- **Key Logic Implementation:**
  - Added `IntakeRecordModel` with a `JSON` column to store heterogeneous mapped data without schema drift issues.
  - Extended `FileManager` with `confirm_and_ingest` to handle the transition from staged file to database records.
  - Used `pandas` for efficient CSV/XLSX parsing and column renaming based on user-confirmed mappings.
- **Files:**
  - `backend/app/infrastructure/api/routes/intake.py`
  - `backend/app/domain/services/file_manager.py`
  - `backend/app/infrastructure/adapters/database/models.py`
  - `backend/tests/infrastructure/api/test_intake.py`
- **Verify:**
  - `poetry run pytest tests/infrastructure/api/test_intake.py` passes.

### Task 4.3: Shared Mapper UI
- **Description:** Build an Angular 21 component to display suggested mappings and allow user modifications.
- **Acceptance:**
  - [x] Headers are displayed in a table with mapping dropdowns.
  - [x] Angular Signals manage the mapping state reactively.
  - [x] Submit button is protected by validation logic (ensuring required fields are mapped).
- **Key Logic Implementation:**
  - Used `signal` and `computed` for clean state management in `SharedMapperComponent`.
  - Integrated Angular Material `MatTable` and `MatSelect` for a premium enterprise feel.
  - Configured `Standalone Component` architecture for better maintainability.
- **Files:**
  - `frontend/src/app/features/intake/shared-mapper.component.ts`
  - `frontend/src/app/features/intake/shared-mapper.component.html`
  - `frontend/src/app/features/intake/shared-mapper.component.spec.ts`
- **Verify:**
  - `npm test` passes for the new component.

## Phase 4 Checkpoint: Shared Mapper
 - [x] Users can upload files and see intelligent mapping suggestions.
 - [x] Mappings can be manually adjusted in a reactive UI.
 - [x] Confirmed data is successfully ingested into PostgreSQL for analysis.

## Phase 5: Compliance Core & Exports

### Task 5.1: Exception Module & Domain Exceptions
- **Description:** Implement a standardized exception handling module to improve debuggability across the application.
- **Acceptance:**
  - [x] Base domain exceptions created in `exceptions/base.py`.
  - [x] Compliance-specific exceptions created in `exceptions/compliance.py`.
  - [x] No `pass` statements in exception class definitions (replaced with explicit logic/constructors).
- **Key Logic Implementation:**
  - Established a hierarchy of domain exceptions starting from `DomainException`.
  - Implemented `AuditDataInconsistencyError` and `MappingError` to provide high-precision error feedback during reconciliation.
- **Files:**
  - `backend/app/domain/exceptions/base.py`
  - `backend/app/domain/exceptions/compliance.py`

### Task 5.2: Date Standardization in Mapping
- **Description:** Ensure all dates ingested are standardized to ISO-8601 strings during the mapping phase.
- **Acceptance:**
  - [x] `FileManager.confirm_and_ingest` automatically parses columns ending in `_date`.
  - [x] Handled various date formats using `pandas.to_datetime()`.
- **Key Logic Implementation:**
  - Updated the ingestion pipeline to detect date-specific mappings.
  - Used `pd.to_datetime` followed by `strftime('%Y-%m-%d')` to guarantee string format consistency for the domain layer.
- **Files:**
  - `backend/app/domain/services/file_manager.py`
  - `backend/tests/domain/services/test_file_manager.py`
- **Verify:**
  - `poetry run pytest tests/domain/services/test_file_manager.py` passes with date parsing verification.

### Task 5.3: Compliance Auditor & Exporter
- **Description:** Implement the Leaver/Mover audit logic and the CSV/PDF generation services.
- **Acceptance:**
  - [x] Leaver/Mover logic correctly identifies access violations after termination.
  - [x] `fpdf2` integrated for auditor-ready PDF reports.
  - [x] CSV export service provides sanitized data for back-system updates.
- **Key Logic Implementation:**
  - **Auditor:** Pure Python domain function that reconciles HR and IT access records using O(1) map lookup for performance.
  - **Exporter:** Leveraged `fpdf2` with custom styling, including risk-level color coding (Red for HIGH risk) in the PDF output.
  - Developed with strict TDD: unit tests for both auditor and exporter drive the implementation.
- **Files:**
  - `backend/app/domain/services/auditor.py`
  - `backend/app/domain/services/exporter.py`
  - `backend/tests/domain/services/test_auditor.py`
  - `backend/tests/domain/services/test_exporter.py`
- **Verify:**
  - Unit tests for Auditor and Exporter pass 100%.

### Task 5.4: Audit API & UI Dashboard
- **Description:** Expose the audit results via REST endpoints and build a reactive Angular dashboard for review and download.
- **Acceptance:**
  - [x] `/audit/leaver-mover` orchestrates DB fetching and domain logic.
  - [x] `/audit/export/csv` and `/audit/export/pdf` provide file downloads.
  - [x] Angular dashboard allows Job selection, displays violations, and handles exports.
- **Key Logic Implementation:**
  - **API:** Implemented endpoints using `Response` with appropriate `media_type` and `Content-Disposition` headers for seamless browser downloads.
  - **UI:** Used **Angular Signals** for reactive state management (`isLoading`, `violations`). Implemented `AuditDashboardComponent` as a standalone module.
  - Fixed `HttpClient` testing issues by removing `HttpClientModule` from standalone component imports, allowing the testing backend to be correctly injected.
- **Files:**
  - `backend/app/infrastructure/api/routes/audit.py`
  - `backend/app/main.py`
  - `backend/tests/infrastructure/api/test_audit.py`
  - `frontend/src/app/features/audit/`
- **Verify:**
  - Integration tests for API endpoints pass.
  - Angular unit tests for the dashboard pass.

## Phase 5 Checkpoint: Compliance Engine & Exports
 - [x] Standardized date parsing ensures reliable cross-silo reconciliation.
 - [x] High-risk leaver/mover violations are automatically detected.
 - [x] Auditor-ready PDF and Sanitized CSV reports are available for download.
 - [x] Reactive dashboard provides a complete audit workflow from trigger to export.