---
App Version: 1.0.0
---

## Objective
Focus: Contextual Schema Injection and UI Workflow Enforcement

## Tech Stack
See [tech_stack.md](tech_stack.md) for the core infrastructure.

## Project Structure
- `frontend/src/app/features/intake/shared-mapper.component.ts` → Updated to support dynamic `@Input()` schemas and autofill logic.
- `frontend/src/app/features/audit/audit-dashboard.component.ts` → Refactored to use `MatStepper` for guided workflows.
- `backend/src/verity_portal/main.py` → Global exception handlers added.
- `backend/src/verity_portal/intake/router.py` → Updated to enforce schema validation.

## Code Style & Standards
Backend Error Handling (FastAPI):
```python
# Custom exception handler in main.py
@app.exception_handler(MappingError)
async def mapping_error_handler(request: Request, exc: MappingError):
    return JSONResponse(
        status_code=400,
        content={"error": "Validation Failed", "message": str(exc)},
    )
```

## Boundaries
- **Always do:** Validate data rigorously on the frontend before submitting to the backend. Ensure backend validation is used purely as a secondary defense layer. Use Angular Material components (`MatSnackBar`) for user feedback.
- **Never do:** Use raw `window.alert` or `console.error` for user feedback.
- **Never do:** Return generic error such as 400 or 500 pages from the API when business logic fails.

---

## Requirements

### FR-5.1.1: Context-Aware Dynamic Mapping
**Architectural Rationale:** Using dynamic inputs for schemas allows the `SharedMapperComponent` to remain a "pure" UI component that is agnostic of the specific business rules (HR vs. IT), which are instead defined at the orchestrator (Dashboard) level.

#### 5.1.1.1. Technical Design Specification
- **Input Signal:** `@Input() requiredSchema` defines the expected fields.
- **Autofill Logic:** Implemented a fuzzy-matching threshold (`confidence > 70`) to reduce manual user effort.
- **State Feedback:** Uses a `Manual Mapping Prompt` to alert users when the system cannot safely auto-map required fields.

#### 5.1.1.2. Implementation Details
- [x] Added `requiredSchema` input to the mapper.
- [x] Implemented confidence-based autofill logic.
- [x] Added visual `required` indicators in the mapping table.

#### 5.1.1.3. Verification Plan
- [x] **Unit Test:** `npm test -- shared-mapper.component.spec.ts`
- [x] **Manual Check:** Verified that fields with 100% name match are automatically assigned on upload.

---

### FR-5.1.2: Guided Audit Workflow (MatStepper)
**Architectural Rationale:** Encapsulating the audit phases within a Stepper prevents invalid state transitions (e.g., running an audit without HR data) and improves overall data integrity.

#### 5.1.2.1. Technical Design Specification
The `AuditDashboardComponent` manages the stepper state and binds the "Completion" signal of each mapper instance to the stepper's `completed` state for each step.

#### 5.1.2.2. Implementation Details
- [x] Integrated `MatStepper` into the dashboard.
- [x] Defined HR, IT, and Audit phases as sequential steps.
- [x] Implemented proactive "Next" button validation.

#### 5.1.2.3. Verification Plan
- [x] **Manual Check:** Confirmed that clicking "Next" is impossible until all required red-asterisk fields are mapped.

---

### FR-5.1.3: Resilient Backend Ingestion
**Architectural Rationale:** Interface-Driven Development (IDD) requires that the backend acts as a strict validator for the frontend. Custom exception handlers ensure that technical stack traces are never leaked to the UI.

#### 5.1.3.1. Technical Design Specification
Implemented a global FastAPI exception handler to intercept `MappingError` and `ComplianceException`, converting them into a standardized `ErrorResponse` model.

#### 5.1.3.2. Implementation Details
- [x] Registered global exception handlers in `main.py`.
- [x] Added `schema_type` validation to the `/intake/confirm` endpoint.
- [x] Integrated `MatSnackBar` for frontend error display.

#### 5.1.3.3. Verification Plan
- [x] **Integration Test:** `pytest tests/test_intake_api.py`
- [x] **Manual Check:** Triggered a manual 400 error and verified the error message appeared in a snackbar.
