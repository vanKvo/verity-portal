# Functional Specification: Phase 5 - Compliance Engine

## Objective
Implement the analytical engine of Verity Portal, enabling automated Leaver/Mover audits and the generation of auditor-ready reports.

## Requirement ID: FR-5.1 – Domain Exception Handling
### Business Context & Rationale (The "Why")
To ensure the system is resilient and easy to debug, we must implement a standardized exception hierarchy. This allows for precise error trapping during complex data reconciliation tasks.

### 5.1.1. Functional Requirements
- **FR-5.1.1: Base Exceptions.** The system shall provide a `DomainException` base class.
- **FR-5.1.2: Audit Specifics.** The system shall implement `MappingError` and `AuditDataInconsistencyError` for data validation failures.

### 5.1.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that invalid data mappings trigger a `MappingError` with a descriptive message.
- **AC 2:** Verify that the system does not crash on data inconsistencies but instead raises an `AuditDataInconsistencyError`.

---

## Requirement ID: FR-5.2 – Date Standardization
### Business Context & Rationale (The "Why")
Reconciliation between HR and IT systems often fails due to mismatched date formats. Standardizing all dates to ISO-8601 ensures that comparisons are reliable and accurate.

### 5.2.1. Functional Requirements
- **FR-5.2.1: Auto-parsing.** The ingestion pipeline shall automatically detect and parse columns mapped to date attributes.
- **FR-5.2.2: ISO-8601 Formatting.** All dates must be stored as standardized ISO-8601 strings in the database.

### 5.2.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that "01/02/2026" is correctly stored as "2026-01-02".
- **AC 2:** Verify that the auditor service can perform chronological comparisons on these fields without error.

---

## Requirement ID: FR-5.3 – Leaver/Mover Audit Logic
### Business Context & Rationale (The "Why")
The primary value of Verity Portal is detecting security violations. The Leaver/Mover audit identifies critical risks where terminated employees still have active system access.

### 5.3.1. Functional Requirements
- **FR-5.3.1: Record Reconciliation.** The system shall reconcile HR "Source of Truth" records with IT "Access" logs.
- **FR-5.3.2: Violation Detection.** The system shall flag any login activity that occurs after a user's termination date as a security violation.

### 5.3.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that an employee with a termination date of 2026-01-01 and a login on 2026-01-05 is correctly flagged as a leaver violation.

---

## Requirement ID: FR-5.4 – Compliance Reporting & Exports
### Business Context & Rationale (The "Why")
Auditors require official, unalterable records of compliance findings. Providing both a human-readable PDF and a machine-readable CSV ensures that findings can be both reviewed and processed by downstream systems.

### 5.4.1. Functional Requirements
- **FR-5.4.1: PDF Export.** The system shall generate styled PDF reports using `fpdf2`, highlighting high-risk violations.
- **FR-5.4.2: CSV Export.** The system shall provide sanitized CSV exports for system-to-system reconciliation.

### 5.4.4. Verification Plan (Acceptance Criteria)
- **AC 1:** Verify that the PDF report contains the Verity Portal branding and a summary of violations.
- **AC 2:** Verify that the CSV export contains all flagged violation data in a consistent tabular format.
