# Phase 5.1: Contextual Intake & UX Hardening - Test Specification

## Objective
Ensure that the Poka-yoke validation layers and guided workflows function correctly, preventing bad data ingestion and surfacing clean errors to the user. Developers must use Test-Driven Development (TDD) where possible, writing these tests *before* finalizing the implementation logic.

---

## Incremental Test Plan

### Problem 1: Generic Intake Context Loss
*Ensuring the system provides the correct context to the user so they know exactly what data is required.*

**Test 1: Schema Autofill & Manual Prompt (Frontend)**
- **Target Component:** `SharedMapperComponent` (`shared-mapper.component.spec.ts`)
- **Setup:** Mount the component and provide an HR `requiredSchema` via `@Input()`. Mock the HTTP client returning the `suggest_mappings` API response.
  - Return `{ 'employee_id': { match: 'Emp_ID', score: 85 }, 'hr_termination_date': { match: 'TermDate', score: 50 } }`.
- **Action:** Trigger the mapping suggestion workflow.
- **Assertion 1:** Verify the internal mapping state is automatically updated to select 'Emp_ID' for `employee_id` because its score is `> 70`.
- **Assertion 2:** Verify `hr_termination_date` is *not* auto-filled because its score is `<= 70`.
- **Assertion 3:** Verify the UI displays the manual mapping prompt: `"Some required fields could not be matched automatically. Please manually map the remaining fields to continue."`

**Test 2: Contextual Schema Injection (Frontend)**
- **Target Component:** `AuditDashboardComponent` (`audit-dashboard.component.spec.ts`)
- **Setup:** Mount the component containing the `MatStepper`.
- **Action:** Inspect the properties passed to the child `app-shared-mapper` components.
- **Assertion:** Verify that Step 1 receives the specific HR schema and Step 2 receives the specific IT schema.

---

### Problem 2: Silent UI Failures during Mapping
*Ensuring the system stops invalid actions explicitly and guides the user to the correct action.*

**Test 3: Stepper Validation Gate (Frontend)**
- **Target Component:** `AuditDashboardComponent` (`audit-dashboard.component.spec.ts`)
- **Setup:** Mount the component containing the `MatStepper`. Provide the HR schema for Step 1.
- **Action:** Leave the `employee_id` unmapped in the Step 1 `SharedMapperComponent` and attempt to trigger the "Next" action to advance to Step 2.
- **Assertion 1:** Verify the stepper's selected index does not change (it does not advance to Step 2).
- **Assertion 2:** Verify the stepper enforces strict sequential validation based on the `required` fields from the injected schema.

**Test 4: Proactive Validation Feedback (Frontend)**
- **Target Component:** `SharedMapperComponent` (`shared-mapper.component.spec.ts`)
- **Setup:** Mount the component. Spy on `MatSnackBar.open`.
- **Action:** Attempt to call the submit/confirm method while a required field is missing.
- **Assertion:** Verify `MatSnackBar.open` was called with actionable text containing the missing field name (e.g., "Action Required: Please map...").

---

### Problem 3: Developer-Centric Backend Errors
*Ensuring backend errors are graceful, human-readable, and properly intercepted by the frontend.*

**Test 5: Backend Error Wrapping (Backend)**
- **Target Route:** Global Exception Handlers (`backend/tests/infrastructure/api/test_error_handlers.py` or similar)
- **Setup:** Create a test route or mock an existing route to artificially raise a `MappingError(["employee_id"])`.
- **Action:** Perform a GET/POST request to that route using the FastAPI `TestClient`.
- **Assertion 1:** Verify the HTTP response status code is `400 Bad Request` (or `422 Unprocessable Entity`).
- **Assertion 2:** Verify the response body JSON matches the exact envelope structure: `{"error": "Validation Failed", "message": "Missing required fields for audit: employee_id"}`.

**Test 6: Backend Schema Enforcement (Backend)**
- **Target Route:** `/intake/confirm/{job_id}` (`backend/tests/infrastructure/api/test_intake.py`)
- **Setup:** Prepare a valid `job_id` with mocked staged file data.
- **Action:** Send a POST request to `/intake/confirm/{job_id}?schema_type=HR_ROSTER` with a JSON mapping payload that is intentionally missing the `hr_termination_date` mapping.
- **Assertion 1:** Verify the endpoint rejects the payload and returns the structured 400 error envelope defined in Test 5.
- **Assertion 2:** Verify the file metadata status in the database was *not* updated to "ingested".

**Test 7: UI Error Interception (Frontend)**
- **Target Component:** `AuditDashboardComponent` (`audit-dashboard.component.spec.ts`)
- **Setup:** Mount the component and mock the `HttpClient`. Spy on the UI alert mechanism (e.g., `MatSnackBar` or internal error signal).
- **Action:** Trigger the `runAudit` method in Step 3. Have the `HttpTestingController` flush a 400 error response with the backend's JSON envelope: `{ error: "Validation Failed", message: "Specific backend error message" }`.
- **Assertion:** Verify that the UI alert mechanism correctly extracted and displayed "Specific backend error message" to the user, rather than failing silently or displaying a generic "Http failure response".
