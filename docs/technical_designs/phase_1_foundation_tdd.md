# Phase 1: Foundation Technical Design

App Version: 1.0.0
## Objective
Focus: Core Infrastructure and Architecture Initialization

## Tech Stack
See [tech_stack.md](tech_stack.md) for the core infrastructure.

## Project Structure
- `backend/src/verity_portal/core/` → Global infrastructure (DB setup, Config, Security).
- `backend/src/verity_portal/shared/` → Reusable domain primitives and utilities.
- `backend/src/verity_portal/[feature]/` → Vertical slices containing `router.py`, `service.py`, `models.py`, and `schemas.py`.
- `frontend/src/app/core/` → Singleton services and guards.
- `frontend/src/app/features/` → Feature-based modules.

## Code Style & Standards
- **Feature-Based Layout:** Code that changes together stays together. Features must communicate via public services, never direct repository imports.
- **Dependency Injection:** Use FastAPI's `Depends()` for database sessions and services.
- **Strict Typing:** Python Type Hints (Pydantic) and TypeScript `interfaces` are mandatory.

## Boundaries
- **Always do:** Protect the API contract using DTOs (`schemas.py`). Never leak SQLAlchemy models to the frontend.
- **Never do:** Put business logic in `router.py`. All logic belongs in `service.py`.

---

## Requirements

### FR-1.1: Backend Foundation (FastAPI & Feature-Based Layout)
**Architectural Rationale:** Organizing by feature (Vertical Slicing) ensures high cohesion and makes the codebase easier to navigate and refactor as individual modules grow.

#### 1.1.1. Technical Design Specification
- **Framework:** FastAPI with Uvicorn.
- **Architecture:** Python Feature-Based Layout (Core, Shared, and Feature Modules).
- **Dependency Management:** Poetry for reproducible builds.

#### 1.1.2. Implementation Details
- [x] Initialized Poetry project.
- [x] Created feature-based directory structure (`core/`, `shared/`, `identity/`).
- [x] Implemented health check endpoint.

#### 1.1.3. Verification Plan
- [x] **Manual Check:** Verify that the backend server starts and responds to a `/health` check.

---

### FR-1.2: Database Foundation (PostgreSQL & Alembic)
**Architectural Rationale:** Using a schema-based migration tool ensures that our PostgreSQL database (specifically the `verity` schema) remains in sync across all environments.

#### 1.2.1. Technical Design Specification
- **Engine:** SQLAlchemy 2.0 with `asyncpg` driver.
- **Migrations:** Alembic configured with autogenerate capabilities.

#### 1.2.2. Implementation Details
- [x] Configured `docker-compose` for local DB development.
- [x] Initialized Alembic.
- [x] Implemented database setup/session factory in `infrastructure/adapters/database/setup.py`.

#### 1.2.3. Verification Plan
- [x] **Manual Check:** Verify that `alembic upgrade head` runs successfully.

---

### FR-1.3: Frontend Foundation (Angular 21 & Jest)
**Architectural Rationale:** Replacing Karma with Jest provides significantly faster test execution and a more modern developer experience.

#### 1.3.1. Technical Design Specification
- **Framework:** Angular Standalone components.
- **Testing:** `jest-preset-angular` for high-speed unit tests.
- **Styling:** Vanilla CSS with Angular Material components.

#### 1.3.2. Implementation Details
- [x] Initialized Angular 21 project.
- [x] Configured Jest and removed Karma/Jasmine.
- [x] Set up base folder structure (`core/`, `shared/`, `features/`).

#### 1.3.3. Verification Plan
- [x] **Unit Test:** `npm test`
