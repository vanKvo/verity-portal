# Functional Specification: Phase 8 - Leaver/Mover Access Restructuring

## Objective
To restructure the Leaver/Mover Access Audit module into a persistent, automated, event-driven auditing system. This phase migrates the module away from manual, session-dependent in-memory runs. The platform will ingest IT Activity logs (system login records) as a managed data type in the Data Hub (cross-referenced with HR Personnel records) via background S3 bucket notifications or manual uploads. Violations will be persistently tracked in the database, displayed in a dedicated dual-tab dashboard (Violations vs. Resolved), and alert security personnel via automated email dispatch.

---

## Requirement ID: FR-8.1 – IT Activity Logs Master Data Ingestion
### Business Context & Rationale (The "Why")
Securing organizational boundaries requires continuous monitoring of user login actions. By ingesting IT activity logs (Active Directory or log server exports) automatically via S3 event notifications or manual file drops through the Shared Column Mapper, we decouple raw event data ingestion from active auditing and maintain a structured historical database of system access.

### User Story
**As a** Security Officer or IT Administrator,  
**I want** the system to automatically ingest and normalize IT activity logs,  
**So that** I have an up-to-date, structured single source of truth for employee system access history.

### Functional Requirements
- **FR-8.1.1: Standard Schema Enforcement.** The system shall enforce a standardized schema for IT Activity records: `employee_id` (String, Index), `last_system_login` (DateTime, required), and optional metadata (`ip_address`, `system_name`).
- **FR-8.1.2: Shared Column Mapper Integration.** The system shall reuse the Shared Column Mapper component to allow users to map custom log spreadsheet headers to system columns during manual uploads.
- **FR-8.1.3: S3 Webhook Dynamic Routing.** The S3 webhook router (`/data-hub/webhooks/s3-ingest`) shall dynamically route file uploads matching key terms like `"it_activity"`, `"access_log"`, or `"active_directory"` to the IT Activity Ingestor.
- **FR-8.1.4: Sync Status Tracking.** The Data Hub UI shall display and support reloading synchronization timestamps for the IT Activity records table.

### User Interaction & Workflow
- **Path A: Background S3 Ingestion:** Active Directory dumps daily login records (`ad_log_dev.csv`) to the `it_activity/` prefix of the S3 bucket. S3 Lambda notifies the webhook, and the background task loads the records.
- **Path B: Manual Upload:** A Security Administrator manually uploads a log file, maps `Employee ID` and `Login Date`, and confirms ingestion.

### Non-Functional Requirements (Constraints)
- **NFR-8.1.1: Authentication.** Manual uploads must require `ROLE_IT` or `ROLE_ECO` permissions.

### Verification Plan (Acceptance Criteria)
- **AC-8.1.1:** Verify that S3 webhook event triggers containing `"it_activity"` in the object key successfully route to the IT Activity Ingestion service.
- **AC-8.1.2:** Verify that manual upload is restricted to users holding `ROLE_IT` or `ROLE_ECO`.

---

## Requirement ID: FR-8.2 – Persistent Access Violation Engine
### Business Context & Rationale (The "Why")
Unauthorized post-termination access (violating NIST SP 800-171 / CMMC AC.L2-3.1.4) cannot be resolved with transient UI warnings. Compliance officers and auditors require persistent, non-repudiable database records showing when violations were detected, who reviewed them, and how they were resolved.

### User Story
**As a** Compliance Auditor or Export Control Officer (ECO),  
**I want** detected leaver access violations to be stored in a database, showing active and resolved events separately,  
**So that** we can track remediation actions and generate compliance reports for external audits.

### Functional Requirements
- **FR-8.2.1: Automated Audit Reconciliation.** When new HR Personnel or IT Activity data is ingested, the engine shall automatically evaluate if `ItActivityModel.last_system_login` is chronologically after `PersonnelModel.termination_date` for matching employees.
- **FR-8.2.2: Violation Persistence.** Any detected discrepancy shall be written to `LeaverViolationModel` with an initial status of `OPEN`.
- **FR-8.2.3: Resolution Workflow.** The system shall expose secure endpoints allowing authorized users to resolve violations by submitting a `resolution_reason` string, transition status to `RESOLVED`, and capture the updating user's identity.
- **FR-8.2.4: Dual-Tab Dashboard.** The frontend UI shall display violations in two distinct views:
  - **Violations Tab:** Grid of all `OPEN` access violations with "Resolve" actions.
  - **Resolved Tab:** Grid of all historical `RESOLVED` records displaying the resolution reasons and dates.

### Role Capabilities & Notifications
- **ROLE_ECO / ROLE_HR**: Full write access to resolve violations and write resolution notes. Receives high-priority email notifications when access violations are detected.
- **ROLE_IT**: Read-only access to retrieve open and resolved violations.

### Verification Plan (Acceptance Criteria)
- **AC-8.2.1:** Verify that a login occurring after an employee's termination date creates a persistent violation in the `OPEN` state.
- **AC-8.2.2:** Verify that submitting a resolution successfully moves the violation to the `RESOLVED` state and writes the resolution notes to the record.

---

## Requirement ID: FR-8.3 – Asynchronous Compliance Alerts
### Business Context & Rationale (The "Why")
Post-termination access represents an active security incident. Security officers need immediate visibility to revoke credentials or freeze accounts rather than discovering the breach during periodic manual dashboard reviews.

### Functional Requirements
- **FR-8.3.1: Automated Email Dispatch.** Upon finding a new leaver access violation during the reconciliation run, the engine shall asynchronously dispatch an email notification to the configured Security Office/ECO mailing list detailing the employee ID and violation specifics.

### Verification Plan (Acceptance Criteria)
- **AC-8.3.1:** Verify that an email notification is dispatched when a new `OPEN` violation is generated by the engine.
