# Functional Specification: Phase 4 - Shared Mapper Service

## Objective
Provide an intelligent data intake system that uses fuzzy logic to bridge the gap between messy source files and standardized system schemas.

## Requirement ID: FR-4.1 – Fuzzy Logic Mapping Suggestions
### Business Context & Rationale (The "Why")
Users often upload files with non-standardized headers (e.g., "Emp Name" instead of "employee_name"). Manual mapping of these fields is time-consuming and error-prone. Fuzzy logic reduces this friction by providing intelligent defaults.

### 4.1.1. Functional Requirements
- **FR-4.1.1: Exact Matching.** Headers that exactly match system attributes must return a 100% confidence score.
- **FR-4.1.2: Fuzzy Matching.** The system shall use `thefuzz` to suggest mappings for non-exact matches with a confidence score > 70%.
- **FR-4.1.3: Normalization.** The mapping engine shall normalize strings (lowercase, removal of special characters) before comparison.

### 4.1.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that "First Name" correctly suggests "first_name" with high confidence.
- **AC 2:** Verify that headers with no close match are left unmapped for user intervention.

---

## Requirement ID: FR-4.2 – Data Ingestion API
### Business Context & Rationale (The "Why")
A robust API is required to handle the multi-stage ingestion process: extracting headers, providing suggestions, and finally persisting the confirmed data.

### 4.2.1. Functional Requirements
- **FR-4.2.1: Header Extraction.** The `/intake/upload` endpoint shall parse CSV/XLSX files and return unique column headers.
- **FR-4.2.2: Mapping Confirmation.** The `/intake/confirm/{job_id}` endpoint shall persist the user-confirmed data into the database.
- **FR-4.2.3: JSONB Persistence.** Data shall be stored in a JSONB format to allow for schema flexibility across different audit types.

### 4.2.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that the upload endpoint returns a valid list of headers for a sample CSV.
- **AC 2:** Verify that confirmed records are visible in the database after the ingestion completes.

---

## Requirement ID: FR-4.3 – Reactive Shared Mapper UI
### Business Context & Rationale (The "Why")
The user must have final authority over data mappings. A reactive, intuitive UI allows them to review system suggestions and make corrections before the data is committed.

### 4.3.1. Functional Requirements
- **FR-4.3.1: Mapping Table.** The UI shall display a table of original headers and corresponding system attribute dropdowns.
- **FR-4.3.2: Reactive State.** The UI shall use Angular Signals to track mapping changes and validation states.
- **FR-4.3.3: Submission Validation.** The system shall prevent submission if any required system attributes remain unmapped.

### 4.3.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that changing a mapping dropdown updates the internal component state immediately.
- **AC 2:** Verify that the "Confirm" button is disabled until all required fields are assigned.
