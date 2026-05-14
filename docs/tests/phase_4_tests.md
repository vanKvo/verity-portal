# Test-Driven Development Spec: Phase 4 (Shared Mapper Service)

Following the **Test-Driven Development (TDD)** guidelines, the developer must start by writing these failing tests before implementing the Phase 4 functionality.

## 1. Backend Unit Tests: Fuzzy Mapping Logic
**Location:** `backend/tests/domain/services/test_mapper.py`
**Type:** Small / Fast (Milliseconds)

### Tests to Write:
- `test_fuzzy_mapper_identifies_exact_matches()`:
  - **Arrange:** Define target schema: `['employee_name', 'citizenship']`. Input headers: `['employee_name', 'citizenship']`.
  - **Act:** Call `suggest_mappings(headers, target_schema)`.
  - **Assert:** Ensure the confidence score is 100 and mapped exactly.
- `test_fuzzy_mapper_identifies_close_matches()`:
  - **Arrange:** Target schema: `['employee_name']`. Input headers: `['Emp Name', 'EmployeeNm']`.
  - **Act:** Call `suggest_mappings()`.
  - **Assert:** Verify `thefuzz` matches "Emp Name" and "EmployeeNm" to "employee_name" with a confidence score > 70.
- `test_fuzzy_mapper_ignores_low_confidence_matches()`:
  - **Arrange:** Target schema: `['employee_name']`. Input headers: `['Random Column 123']`.
  - **Act:** Call `suggest_mappings()`.
  - **Assert:** Verify it returns no suggestion (or null/empty) when the score is below the acceptable threshold.

## 2. Backend Integration Tests: API Endpoints
**Location:** `backend/tests/infrastructure/api/routes/test_intake.py`
**Type:** Medium (Seconds)
**Mocking Strategy:** Use FastAPI's `TestClient`.

### Tests to Write:
- `test_upload_endpoint_accepts_valid_csv_and_returns_suggestions()`:
  - **Arrange:** Create a mock CSV file in memory using Python's `io.StringIO`.
  - **Act:** Post to `/intake/upload` via `TestClient`.
  - **Assert:** Expect `200 OK`. Verify the JSON response contains extracted `headers` and `suggestions`.
- `test_upload_endpoint_enforces_50mb_limit()`:
  - **Act:** Attempt to POST a file larger than 50MB.
  - **Assert:** Expect `413 Payload Too Large`.
- `test_confirm_mapping_endpoint_triggers_database_save()`:
  - **Arrange:** POST confirmed mappings to `/intake/confirm/{job_id}`.
  - **Assert:** Verify it responds with `200 OK` and check the test database to ensure the data was ingested into PostgreSQL as JSONB.

## 3. Frontend Unit Tests: Angular UI Components
**Location:** `frontend/src/app/features/intake/shared-mapper.component.spec.ts`
**Type:** Medium (Runs via Jest)

### Tests to Write:
- `test_displays_dropdowns_for_extracted_headers()`:
  - **Arrange:** Set the component's `headers` signal to `['Emp Name', 'Status']`.
  - **Act:** Trigger change detection.
  - **Assert:** Query the DOM to verify two dropdown elements (`<mat-select>`) are rendered.
- `test_updates_mapping_signal_on_dropdown_selection()`:
  - **Arrange:** Render the component.
  - **Act:** Simulate a user selecting 'employee_name' from the dropdown for the 'Emp Name' header.
  - **Assert:** Verify the component's `mappings` signal state is `{ 'Emp Name': 'employee_name' }`.
- `test_submit_button_disabled_if_required_mappings_missing()`:
  - **Arrange:** Define 'employee_name' as a required field for the ITAR schema. Leave it unmapped.
  - **Act/Assert:** Verify the Submit `<button>` has the `disabled` attribute.

## Implementation Checklist for Developer
1. Write backend mapping logic tests in `test_mapper.py` -> See fail.
2. Implement `suggest_mappings()` -> See pass.
3. Write FastAPI route tests in `test_intake.py` -> See fail.
4. Implement `/intake/upload` -> See pass.
5. Write Angular Jest tests in `shared-mapper.component.spec.ts` -> See fail.
6. Implement `SharedMapperComponent` UI and Signals -> See pass.
