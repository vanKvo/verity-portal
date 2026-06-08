# Technical Design Document: Phase 8 - Leaver/Mover Access Restructuring

App Version: 1.0.0

---

## 1. System Architecture

### Tech Stack
- **Base Stack:** See [tech_stack.md](../technical_designs/tech_stack.md)
- **Module Specific:** No new external libraries introduced. Uses `pandas` for log parsing and `sqlalchemy` for persistence.

### Project Structure
- `src/verity_portal/data_hub/it_activity/` → Contains models, schemas, and service layers for storing IT Activity/system login logs.
- `src/verity_portal/audit/models.py` → [NEW] Contains SQLAlchemy models for the persistent leaver/mover violations and statuses.
- `src/verity_portal/audit/engine.py` → [NEW] Houses the `LeaverMoverReconciliationEngine` logic for running queries and generating alerts.
- `src/verity_portal/audit/router.py` → Exposes endpoints to fetch, export, and resolve persistent access violations.

### Boundaries
- **Always do:** Rely on the `DataHubOrchestrationService` to coordinate webhook events and trigger downstream reconciliation engines.
- **Always do:** Separate business logic from the REST API router or controller page.
- **Never do:** Write database commits or email-dispatching commands directly inside routing scripts (`router.py`).

---

## 2. Global Technical Context (The Contracts)

### Data Model & Storage

#### `ItActivityModel` (Schema: `verity`, Table: `it_activity`)
Stores normalized system login times.
- `id`: Uuid(as_uuid=True), Primary Key
- `employee_id`: String(50), Index, Unique (represents latest system login metadata per employee)
- `last_system_login`: DateTime, Nullable = False
- `ip_address`: String(45), Nullable = True
- `system_name`: String(100), Nullable = True
- `created_at`: DateTime(timezone=True), default=func.now()
- `updated_at`: DateTime(timezone=True), default=func.now(), onupdate=func.now()

#### `LeaverViolationModel` (Schema: `verity`, Table: `leaver_violations`)
Tracks post-termination access violations and resolutions.
- `id`: Uuid(as_uuid=True), Primary Key
- `employee_id`: String(50), ForeignKey("verity.personnel.employee_id")
- `hr_termination_date`: Date, Nullable = False
- `last_system_login`: DateTime, Nullable = False
- `status`: Enum('OPEN', 'RESOLVED'), Default: 'OPEN'
- `resolution_reason`: String(500), Nullable = True
- `resolved_by`: String(255), Nullable = True
- `resolved_at`: DateTime(timezone=True), Nullable = True
- `created_at`: DateTime(timezone=True), default=func.now()
- `updated_at`: DateTime(timezone=True), default=func.now(), onupdate=func.now()

### API Specifications & Security (RBAC)
- `POST /data-hub/it-activity/upload` (Requires: `ROLE_IT` or `ROLE_ECO`): Uploads IT activity logs.
- `GET /audit/leaver-mover/violations` (Requires: `ROLE_ECO` or `ROLE_HR` or `ROLE_IT`): Retrieves open or resolved violations.
- `POST /audit/leaver-mover/violations/{id}/resolve` (Requires: `ROLE_ECO` or `ROLE_HR`): Resolves a violation.
- `POST /data-hub/webhooks/s3-ingest` (Requires: valid webhook token): Routes keys containing `"it_activity"`, `"access_log"`, or `"active_directory"` to the IT Activity Ingestor.

### Event Interfaces (Asynchronous)
- **Subscribes To:** S3 `ObjectCreated` notification webhooks.
- **Publishes:** Asynchronous email alert notifications to security officers (`BaseEmailService.send_alert`) when a post-termination login violation is detected.

### Error Handling Strategy
- Raise `ComplianceError` mapped to `422 Unprocessable Entity` if ingestion fails or date validations are violated.
- Raise `AuthorizationError` mapped to `403 Forbidden` if unauthorized roles attempt to resolve compliance violations.

---

## 3. Feature Implementation Breakdown

### Requirement ID: FR-8.1 - IT Activity Logs Master Data Ingestion
**Architectural Rationale:** Establishing IT Activity records as a structured, normalized collection in the Data Hub isolates logging activity data collection from dynamic validation logic.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** Expose `POST /data-hub/it-activity/upload` under `data_hub/router.py` with `ROLE_IT` or `ROLE_ECO` checks.
- **Service Layer:** Create `ItActivityService` extending the `MasterDataIngestor` engine.
- **Webhook Integration:** Add routing rules in `DataHubOrchestrationService.perform_s3_ingestion` to identify `"it_activity"`, `"access_log"`, or `"active_directory"` file tags, parse them, and run the ingestion service.
- **Status Endpoint:** Update `/sync-status` to return `it_activity_last_sync`.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** In `DataHubComponent`, add a tab for "IT Activity Logs" and display its `last_sync` status card.
- **State & Service:** Integrate file mapping and upload hooks for IT Activity files.

#### Implementation Tasks
- [ ] **[Backend]** Create Alembic migration for `it_activity` and `leaver_violations` tables.
- [ ] **[Backend]** Implement `ItActivityModel` and `ItActivityMasterSchema`.
- [ ] **[Backend]** Create `ItActivityService` and wire up manual upload and webhook routes.
- [ ] **[Frontend]** Add the IT Activity Logs tab and status cards in the Data Hub UI.

#### Verification Plan
- [ ] **[Backend]** Verify unit test: `ItActivityService.ingest_master_data` correctly processes dataframes and updates `it_activity` records.
- [ ] **[Frontend]** Verify that the IT Activity tab is only visible to `ROLE_IT` or `ROLE_ECO` and triggers manual uploads correctly.

---

### Requirement ID: FR-8.2 - Persistent Access Violation Engine
**Architectural Rationale:** Relational persistent storage of violations prevents security discrepancies from getting lost between user sessions and provides audit compliance trails.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** Implement `GET /audit/leaver-mover/violations` and `POST /audit/leaver-mover/violations/{id}/resolve`.
- **Service Layer:** Build `LeaverMoverReconciliationEngine` that runs a query joining `PersonnelModel` (where `termination_date` is not null) and `ItActivityModel` (where `last_system_login > termination_date`).
- **Data Access:** Insert matching records into `LeaverViolationModel`. Manage state transition from `OPEN` to `RESOLVED` on resolution.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** Redesign the Leaver/Mover audit interface into a tabbed component with "Violations" and "Resolved" tables.
- **State & Service:** Implement a resolution dialog triggered by clicking "Resolve", prompting the user for a resolution note and calling `/resolve`.

#### Implementation Tasks
- [ ] **[Backend]** Implement the `LeaverMoverReconciliationEngine` class.
- [ ] **[Backend]** Create violation retrieval and resolution endpoints in `audit/router.py`.
- [ ] **[Frontend]** Build the tabbed Leaver/Mover violations view and the resolution modal dialog.

#### Verification Plan
- [ ] **[Backend]** Verify unit test: Query correctly captures logins occurring strictly after termination date.
- [ ] **[Frontend]** Verify UI integration: Click "Resolve", submit note, and ensure it moves immediately to the "Resolved" tab.

---

### Requirement ID: FR-8.3 - Asynchronous Compliance Alerts
**Architectural Rationale:** Real-time visibility of security breaches prevents active unauthorized system access.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Notification Logic:** Integrate `BaseEmailService.send_alert` within the reconciliation engine run. Trigger an email notification listing the employee ID and violation description for newly discovered violations.

#### Implementation Tasks
- [ ] **[Backend]** Integrate `self.email_service.send_alert` calls inside the reconciliation engine violation loop.

#### Verification Plan
- [ ] **[Backend]** Verify unit test: Mocking the email service confirms alerts are sent upon violation detection.
