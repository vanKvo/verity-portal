---
App Version: 1.0.0
---

## Objective
Focus: Modular File Intake and UI Flow Optimization

## Tech Stack
See [tech_stack.md](tech_stack.md) for the core infrastructure.

## Project Structure
- `frontend/src/app/features/intake/file-upload.component.ts` → Standalone component for dropzone and HTTP logic.
- `frontend/src/app/features/intake/file-upload.component.html` → Template for dropzone and progress feedback.
- `frontend/src/app/features/audit/audit-dashboard.component.ts` → Orchestrator for the intake-to-mapper transition.
- `frontend/src/app/features/intake/shared-mapper.component.ts` → Data-driven mapper accepting external headers/suggestions.

## Code Style & Standards
**Event-Driven Communication:** Components must communicate via outputs to maintain decoupling.
```typescript
@Output() onUploadSuccess = new EventEmitter<{jobId: string, headers: string[], suggestions: any[]}>();

uploadFile(file: File) {
  // ... upload logic ...
  this.onUploadSuccess.emit({ jobId, headers, suggestions });
}
```

## Boundaries
- **Always do:** Isolate the file upload logic in its own component to maintain the Single Responsibility Principle.
- **Always do:** Use `crypto.randomUUID()` on the frontend for secure session tracking.
- **Never do:** Put drag-and-drop `@HostListener` directives directly into the `AuditDashboardComponent`.
- **Never do:** Allow file uploads without checking the extension against `allowedExtensions`.

---

## Requirements

### FR-5.2.1: Drag-and-Drop File Intake
**Architectural Rationale:** Transitioning from manual Job ID entry to a modular, event-driven intake component reduces user friction and encapsulates the complex logic of file handling and UUID generation.

#### 5.2.1.1. Technical Design Specification
The `FileUploadComponent` is a standalone, reusable element that manages its own internal state via Angular Signals.
- **State Management:** Uses `isDragging`, `isUploading`, and `errorMessage` signals for reactive UI updates.
- **Interaction:** Employs `@HostListener` to intercept native browser drag/drop events.

#### 5.2.1.2. Implementation Details
- [x] Created standalone `FileUploadComponent`.
- [x] Implemented native drag-and-drop logic with visual feedback.
- [x] Automated the upload process using `FormData` and UUID generation.
- [x] Added extension validation for `.csv`, `.xlsx`, and `.xls`.

#### 5.2.1.3. Verification Plan
- [x] **Unit Test:** Verified signal state changes and drag-and-drop event handling in `file-upload.component.spec.ts`.
- [x] **Manual Check:** Dropped a valid CSV and verified the backend `/intake/upload` was called with a generated UUID.

---

### FR-5.2.2: Modular Component Orchestration
**Architectural Rationale:** By decoupling the upload logic from the mapping logic, we maintain the Single Responsibility Principle. The dashboard acts as a "Smart Orchestrator" that bridges these modules via standard events.

#### 5.2.2.1. Technical Design Specification
The `AuditDashboardComponent` acts as the orchestrator, listening for `onUploadSuccess` and dynamically populating the `SharedMapperComponent` through property binding.

#### 5.2.2.2. Implementation Details
- [x] Refactored `SharedMapperComponent` to use read-only `input()` signals.
- [x] Replaced Job ID manual inputs in `AuditDashboardComponent` with `app-file-upload`.
- [x] Wired up upload success events to mapper visibility and data signals.

#### 5.2.2.3. Verification Plan
- [x] **Integration Test:** Verified that `onUploadSuccess` emission correctly updates the dashboard's visibility signals.
- [x] **Manual Check:** Uploaded an HR file and verified the mapper automatically appeared with the correct column headers.

---

### FR-5.2.3: Automated Workflow Progression & Type Safety
**Architectural Rationale:** A seamless user journey is achieved through automated state signals (`onConfirm`). Enforcing strict types (No Any) across the API boundary eliminates "type drifting" and ensures contract integrity between Angular and FastAPI.

#### 5.2.3.1. Technical Design Specification
All backend responses are mapped to formal TypeScript interfaces to prevent runtime errors and catch schema mismatches at compile-time.
- **Service Layer Architecture:** Centralized all `/intake` API interactions into `SharedMapperService` to decouple components from HTTP implementation.
- **Body-Based API Contract:** Updated `POST /intake/confirm/{job_id}` to accept a JSON body (via `ConfirmMappingRequest` Pydantic model) instead of query parameters, improving security and payload structure.
- **Interfaces:** `UploadResponse`, `ConfirmMappingResponse`, `IntakeSuggestion`.

#### 5.2.3.2. Implementation Details
- [x] Refactored intake confirmation to use dedicated `SharedMapperService`.
- [x] Updated backend API to accept parameters in JSON request body.
- [x] Implemented Pydantic model for `ConfirmMappingRequest` validation.
- [x] Implemented `onConfirm` output signal in `SharedMapperComponent`.
- [x] Bound mapping success to `stepper.next()` in the dashboard for automatic flow.
- [x] Eliminated all `any` types in the feature logic.
- [x] Added `isProcessing` indicators for loading state feedback.

#### 5.2.3.3. Verification Plan
- [x] **Backend Test:** Verified body-based confirm contract in `test_intake.py`.
- [x] **Type Check:** Confirmed that `shared-mapper.service.ts` no longer contains the `any` type.
- [x] **Manual Check:** Clicking "Confirm & Process" now moves the stepper to the next stage automatically upon success.
