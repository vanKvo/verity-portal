1. Install Alembic (Python database migration script)
poetry run alembic revision -m "initial migration" && poetry run alembic upgrade head

2. Create Core and Shared module
mkdir -p src/app/core/guards src/app/core/interceptors src/app/core/services src/app/shared/components src/app/shared/directives src/app/shared/pipes src/app/features/auth src/app/features/intake src/app/features/itar-audit

3. Swapping out Karma (and Jasmine) for Jest. In the Angular ecosystem, this has become a very common move because Jest is generally faster and easier to configure for modern CI/CD pipelines.
npm uninstall karma karma-chrome-launcher karma-coverage karma-jasmine karma-jasmine-html-reporter && npm install --save-dev jest jest-preset-angular @types/jest

4. Check if Jest is running
npm test

5. Verify that the necessary setup files are present in node_modules after installation (specifically looking for setup-jest, which provides the necessary global configuration for running Jasmine-style tests in the Jest environment)
ls -R node_modules/jest-preset-angular | grep setup-jest

6. Find setup-jest.js file location
find node_modules/jest-preset-angular -name "setup-jest.js"

7. 
npm install zone.js

## Phase 2 Checkpoint: User & Session
 User logs in successfully using the FastAPI backend. The backend creates a session in PostgreSQL and returns a JWT token.
 The token is stored securely on the frontend (in memory or HttpOnly cookie).

Verify database models
poetry run pytest tests/infrastructure/adapters/test_database_models.py

## Phase 3: File Management Service.
- mkdir -p backend/tests/infrastructure/adapters/storage
- poetry run pytest backend/tests/infrastructure/adapters/storage/test_local_adapter.py
**aiofiles**: Used for handling local file I/O asynchronously.
**python-multipart**: Required by frameworks like FastAPI to parse form data and file uploads.
- poetry add aiofiles python-multipart
- poetry run pytest tests/infrastructure/adapters/storage/test_local_adapter.py
- poetry add --group dev pytest-asyncio
- poetry run pytest tests/infrastructure/adapters/storage/test_local_adapter.py
- docker ps
- poetry run alembic revision --autogenerate -m "add file metadata table"
- poetry run alembic upgrade head
- mkdir -p backend/tests/domain/services
- poetry run pytest tests/domain/services/test_file_manager.py
### Fix the issue where file_metadata table was not created.
**Problem:** 
- Model Discovery: The models were not imported in alembic/env.py, preventing Alembic's autogenerate feature from detecting them.
- Schema Context: The verity schema was not configured in the models or in Alembic's detection logic, so the tables were either not created or were defaulting to the public schema.
**Actions Taken:**
- Model Updates: Added __table_args__ = {"schema": "verity"} to both UserModel and FileMetadataModel in backend/app/infrastructure/adapters/database/models.py.
- Alembic Configuration: Updated backend/alembic/env.py to import the models and enabled include_schemas=True so Alembic can manage the verity schema.
- New Migration: Regenerated the migration script fa38a300acde_add_file_metadata_table.py
**Commands Used:**
- poetry run alembic downgrade 6c4d75d678cb && rm alembic/versions/cfc7b0228323_add_file_metadata_table.py
- poetry run alembic revision --autogenerate -m "add file metadata table"
- poetry run alembic upgrade head
- docker exec verity-db psql -U user -d verity_db -c "\dt verity.*"

## Phase 4: Shared Mapper Service
### Backend
- poetry add thefuzz python-Levenshtein pandas openpyxl
- mkdir -p backend/tests/infrastructure/api
After writing tests in test_intake.py:
- poetry run pytest tests/infrastructure/api/test_intake.py
Implement functions in mapper.py and intake.py
- poetry run pytest tests/infrastructure/api/test_intake.py
Implement mapper.py. Write and test with failed tests first before implementingn the logic to make the tests passed.
- poetry run pytest tests/domain/services/test_mapper.py
Try several different scenarios to create functions in mapper.py
- poetry run python .gemini/antigravity/brain/ae730163-af46-428b-b608-0a287f6bcb52/scratch/debug_mapper.py
- poetry run python /Users/gabong/Documents/Programming/verity-portal/.gemini/antigravity/brain/ae730163-af46-428b-b608-0a287f6bcb52/scratch/debug_mapper.py
- poetry run python /Users/gabong/Documents/Programming/verity-portal/.gemini/antigravity/brain/ae730163-af46-428b-b608-0a287f6bcb52/scratch/debug_mapper_v2.py
- poetry run python /Users/gabong/Documents/Programming/verity-portal/.gemini/antigravity/brain/ae730163-af46-428b-b608-0a287f6bcb52/scratch/debug_mapper_v3.py
Implement intake.py
- poetry run pytest tests/infrastructure/api/test_intake.py
- poetry run pytest tests/infrastructure/api/test_intake.py::test_confirm_mapping_success -vv
### Frontend
- ls -R frontend/src/app/features/intake/
- mkdir -p src/app/features/intake
- npm test
- tail -n 10 /Users/gabong/Documents/Programming/verity-portal/docs/implementation.md

## Phase 5: Compliance Core & Exports

### 1. Date Standardization (Mapping Layer)
**Thought Process:**
Compliance reconciliation depends on accurate date comparisons. If IT logs use `10/01/2023` and HR logs use `2023-10-01`, comparisons fail. I decided to standardize all dates at the "ingestion perimeter" (mapping phase) using `pandas`. This keeps the Auditor domain logic "pure" and format-agnostic.
**Commands:**
- `poetry run pytest tests/domain/services/test_file_manager.py` (Verified that columns ending in `_date` are correctly cast to ISO strings).

### 2. Industry Standard Exception Handling
**Thought Process:**
The user requested "industry standard" exceptions with "no pass" statements. I created a hierarchical module in `domain/exceptions/`.
- `DomainException`: Base class to differentiate from generic Python errors.
- `ComplianceException`: Categorized errors for easier API mapping.
- Rationale: Using specific exceptions allows the infrastructure layer (FastAPI) to return high-precision error messages (e.g., `422 Unprocessable Entity` for data inconsistencies vs `500` for system crashes).

### 3. Compliance Auditor (TDD)
**Thought Process:**
Built the `audit_leaver_mover` service using O(1) lookups. By mapping HR records to a dictionary by `employee_id`, we avoid O(n²) nested loops, ensuring the engine performs well even with 10k+ records.
**Commands:**
- `poetry run pytest tests/domain/services/test_auditor.py` (5 tests passed).

### 4. Exporter Service (PDF & CSV)
**Thought Process:**
Automating the "Auditor PDF" was a priority. 
- Installed `fpdf2` for modern PDF generation.
- **Problem:** Encountered `AttributeError` for deprecated `ln=True` and missing `get_creation_date` in the latest `fpdf2`.
- **Solution:** Switched to `new_x`/`new_y` positioning and used standard `datetime` library for timestamps.
**Commands:**
- `poetry add fpdf2`
- `poetry run pytest tests/domain/services/test_exporter.py` (Handled `bytearray` vs `bytes` return type mismatch).

### 5. API & UI Integration
**Thought Process:**
The API layer acts as a bridge. I implemented `StreamingResponse` logic (via `Response` content) to handle binary file downloads.
On the frontend, I used **Angular Signals** for real-time loading states.
- **Critical Fix:** During testing, the `HttpClient` mock wouldn't trigger. I identified that the standalone component was importing `HttpClientModule`, which created a local instance of the client that ignored the test backend. Removing the import and using `provideHttpClientTesting()` solved the issue.
**Commands:**
- `poetry run pytest tests/infrastructure/api/test_audit.py`
- `npm install @angular/animations@^21.2.0 --legacy-peer-deps`
- `npm install @angular/platform-browser-dynamic@^21.2.0 --legacy-peer-deps`
- `npm test` (7 tests passed across suites).

# Phase 5.1: Context intake and UX hardening
## Frontend
npm test -- src/app/features/intake/shared-mapper.component.spec.ts