---
App Version: 1.0.0
---

## Objective
This specification details the implementation steps for adding robust frontend validation, contextual schema injection, and graceful backend error handling to the Verity Portal. Developers must implement these tasks incrementally, verifying functionality before proceeding to the next.

## Requirement ID: FR-5.1.1 – Dynamic Schema Injection (Context-Aware Mapping)
### Business Context & Rationale (The "Why")
Previously, the intake system used a hardcoded target schema, making it difficult for users to know which fields were required for specific audit types (e.g., HR vs. IT). By introducing dynamic, context-aware schemas, we reduce cognitive load and prevent data entry errors.

### 5.1.1.1. Functional Requirements
- **FR-5.1.1.1: Dynamic Schema Injection.** The mapper shall accept a dynamic `requiredSchema` input that defines the target fields for the current context.
- **FR-5.1.1.2: Intelligent Autofill.** The system shall automatically map incoming columns if the backend suggestion confidence score is greater than 70%.
- **FR-5.1.1.3: Visual Requirement Cues.** Required fields within the mapping table must be visually highlighted (e.g., via a red asterisk).

### 5.1.1.2. User Interaction & Workflow
#### Path 1: Basic Flow (The Happy Path)
- User selects an audit type (e.g., HR Roster).
- System injects the relevant schema into the mapper.
- User uploads a file.
- System automatically maps "Exact Matches" and high-confidence suggestions.
- User sees a "Mapping Complete" indicator.

#### Path 2: Exception Flows (Errors & Edge Cases)
- **Exc-A: Low Confidence Matches:** If confidence is <= 70%, the system leaves the field unmapped and prompts the user: "Some required fields could not be matched automatically."

### 5.1.1.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that fields marked `required: true` in the schema display a red asterisk in the UI.
- **AC 2:** Verify that suggestions with confidence > 70 are applied to the state automatically.

---

## Requirement ID: FR-5.1.2 – MatStepper Integration (Guided Audit Workflow)
### Business Context & Rationale (The "Why")
Audit data ingestion is a multi-step process (HR Records -> IT Logs -> Run Audit). Using a guided "Wizard" interface (Stepper) ensures that users follow the correct sequence and do not miss critical data steps.

### 5.1.2.1. Functional Requirements
- **FR-5.1.2.1: Sequential Step Enforcement.** The UI shall use an Angular Material Stepper to guide the user through the HR, IT, and Audit Run phases.
- **FR-5.1.2.2: Proactive Step Validation.** The "Next" button for a given step shall remain disabled until all required mappings for that step are completed.

### 5.1.2.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that the "Next" button in Step 1 is disabled if required HR fields are unmapped.
- **AC 2:** Verify that the user can navigate back to previous steps without losing current mapping state.

---

## Requirement ID: FR-5.1.3 – Structured Backend Error Envelopes (Resilient Ingestion)
### Business Context & Rationale (The "Why")
Backend errors should never be "silent" or developer-centric. Structured error responses ensure that if a mapping fails server-side, the user receives a helpful notification rather than a broken UI.

### 5.1.3.1. Functional Requirements
- **FR-5.1.3.1: Structured Domain Exceptions.** The backend shall wrap domain-specific errors (e.g., MappingError) in a standardized JSON envelope.
- **FR-5.1.3.2: Schema Integrity Backup.** The `/intake/confirm` endpoint shall validate the payload against the expected schema type before processing.

### 5.1.3.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that a 400 error from the API triggers a `MatSnackBar` notification in the frontend with a human-readable message.

