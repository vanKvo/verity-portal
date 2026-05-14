---
App Version: 1.0.0
---

## Objective
Replace the manual Job ID text entry with an intuitive drag-and-drop file upload dropbox. This component will handle file validation, uploading, and seamlessly pass the resulting dataset (headers, suggestions, job ID) to the contextual mapper without manual user intervention.

## Requirement ID: FR-5.2.1 – Native Drag-and-Drop File Intake
### Business Context & Rationale (The "Why")
Manual entry of alphanumeric "Job IDs" is prone to human error and creates significant friction in the intake process. Transitioning to a drag-and-drop interface aligns with modern enterprise UX standards and reduces the technical burden on the end-user.

### 5.2.1.1. Functional Requirements
- **FR-5.2.1.1: Multi-Format Support.** The system shall support drag-and-drop intake for `.csv`, `.xlsx`, and `.xls` files.
- **FR-5.2.1.2: Visual State Feedback.** The dropzone shall change visual state (highlighting/scaling) when a valid file is hovered over the target area.
- **FR-5.2.1.3: Extension Validation.** The system shall immediately reject files with unsupported extensions before attempting a server-side upload.
- **FR-5.2.1.4: Real-time Upload Progress.** A visual indicator (progress spinner) must be displayed to inform the user that the file is being processed.

### 5.2.1.2. User Interaction & Workflow
#### Path 1: Basic Flow (The Happy Path)
- User navigates to the Audit Dashboard.
- User drags a local HR Master CSV file into the designated upload zone.
- Dropzone highlights to confirm engagement.
- System validates extension and starts the upload.
- System displays success state and automatically populates the mapping table.

#### Path 2: Exception Flows (Errors & Edge Cases)
- **Exc-A: Unsupported File Type:** User drops a `.pdf`. System displays an "Invalid File Extension" error and blocks the upload.
- **Exc-B: Upload Interruption:** Network drops during upload. System displays a "Retry" prompt.

### 5.2.1.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that a successful drop triggers the backend `/intake/upload` endpoint.
- **AC 2:** Verify that the UI remains responsive and provides a loading spinner during the upload duration.

---

## Requirement ID: FR-5.2.2 – Service Layer Refactoring (Modular Orchestration)
### Business Context & Rationale (The "Why")
To ensure long-term maintainability and prevent the "Audit Dashboard" from becoming a bloated monolith, the upload and mapping logic must be decoupled. This allows the reuse of the same mapping technology for other modules (e.g., Policy or IT asset intake) without duplicating code.

### 5.2.2.1. Functional Requirements
- **FR-5.2.2.1: Event-Driven Architecture.** The file upload component shall remain agnostic of the audit logic, communicating only via standardized data events (`onUploadSuccess`).
- **FR-5.2.2.2: Contextual Mapping Hand-off.** The dashboard shall listen for upload events and automatically feed the resulting headers and suggestions into the mapper component.

### 5.2.2.2. User Interaction & Workflow
#### Path 1: Basic Flow (The Happy Path)
- System detects an `onUploadSuccess` event from the uploader.
- Dashboard automatically reveals the `SharedMapperComponent`.
- System maps the backend suggestions into the mapper's internal state.

### 5.2.2.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that the Mapper component remains hidden until a successful file upload occurs.
- **AC 2:** Verify that the "Suggestions" provided by the backend are automatically reflected in the mapper dropdowns without user re-entry.

---

## Requirement ID: FR-5.2.3 – Body-Based API Contract (Automated Progression & Type Safety)
### Business Context & Rationale (The "Why")
A seamless "Wizard" experience requires the UI to move to the next logical step automatically once a sub-task is finished. Additionally, enforcing strict type safety ensures that backend schema changes are caught during development rather than by the end-user at runtime.

### 5.2.3.1. Functional Requirements
- **FR-5.2.3.1: Automated State Advancement.** Upon receipt of a successful mapping confirmation, the system shall automatically trigger the stepper to move to the next logical stage.
- **FR-5.2.3.2: Processing Indicators.** The UI shall provide visual feedback via an `isProcessing` signal during the asynchronous ingestion period.
- **FR-5.2.3.3: Strict Data Integrity.** The system shall enforce a strict interface contract between the frontend and backend, eliminating the use of the `any` type for API responses.

### 5.2.3.2. User Interaction & Workflow
#### Path 1: Basic Flow (The Happy Path)
- User clicks "Confirm & Process" on a complete mapping.
- System displays "Processing..." state on the button.
- Upon 200 OK, the stepper automatically moves to the next step.

### 5.2.3.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that clicking "Confirm & Process" advances the UI to the next step upon a 200 OK response.
- **AC 2:** Verify that all data objects (UploadResponse, ConfirmMappingResponse) strictly match the backend API contract at compile-time.
-time.