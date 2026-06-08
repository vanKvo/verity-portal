# Phase 8: Leaver/Mover Access Restructuring - Test Specification

## Objective
Verify the secure ingestion of IT Activity logs (system login records) via automated S3 webhook routing and manual uploads, and ensure the Leaver/Mover Access Reconciliation Engine accurately identifies compliance violations (system access logged after termination). Also, validate persistent database violation status tracking (OPEN vs. RESOLVED), role-based resolution controls, read-only permissions for IT, and automatic email dispatch triggers.

---

## Incremental Test Plan by Functional Requirements

### FR-8.1: IT Activity Logs Master Data Ingestion
*[Ensures login logs are correctly ingested via S3 event notifications and manual overrides, respecting strict RBAC boundaries.]*

**Test 1: S3 Webhook Dynamic Routing (Backend)**
- **Purpose:** Verify the S3 webhook router correctly identifies IT Activity logs based on filename keywords and routes processing to `ItActivityService`.
- **Test name:** `test_s3_webhook_routes_it_activity` 
- **Target Route:** `POST /data-hub/webhooks/s3-ingest` (`src/verity_portal/data_hub/router.py`)
- **Setup:** Mock an AWS EventBridge S3 payload containing `active_directory_log_2026.csv`.
- **Action:** POST the payload to the webhook endpoint.
- **Assertion 1:** The webhook dynamically schedules a background task routing to `ItActivityService.ingest_master_data`.
- **Assertion 2:** The response code is 200 OK.

**Test 2: Manual Upload Authorization (Backend)**
- **Purpose:** Ensure role-based access control grants upload rights to IT/ECO but restricts other roles.
- **Test name:** `test_it_activity_upload_rbac` 
- **Target Route:** `POST /data-hub/it-activity/upload` (`src/verity_portal/data_hub/router.py`)
- **Setup:** Create test users with `ROLE_IT`, `ROLE_ECO`, and `ROLE_PM`.
- **Action:** Post an activity log CSV file to the endpoint.
- **Assertion 1:** Both `ROLE_IT` and `ROLE_ECO` receive a 200 OK status code.
- **Assertion 2:** `ROLE_PM` is blocked with a 403 Forbidden status code.

---

### FR-8.2: Persistent Access Violation Engine
*[Ensures access violations are captured, stored, and resolved under proper security constraints.]*

**Test 3: Post-Termination Access Detection (Backend)**
- **Purpose:** Verify the reconciliation engine flags system access logged after termination.
- **Test name:** `test_reconciliation_detects_post_termination_access` 
- **Target Service:** `LeaverMoverReconciliationEngine.run_audit()` (`src/verity_portal/audit/engine.py`)
- **Setup:** Seed `PersonnelModel` with a terminated employee (`termination_date = 2026-05-01`). Seed `ItActivityModel` with a login (`last_system_login = 2026-05-15`) for the same employee.
- **Action:** Execute the reconciliation engine.
- **Assertion 1:** A new `LeaverViolationModel` record is created with `status: OPEN`.
- **Assertion 2:** The violation records the correct `employee_id`, `hr_termination_date`, and `last_system_login`.

**Test 4: Violations Retrieval Authorization (Backend)**
- **Purpose:** Ensure IT, ECO, and HR roles can fetch open/resolved violations, while blocking unauthorized roles.
- **Test name:** `test_violations_retrieval_rbac` 
- **Target Route:** `GET /audit/leaver-mover/violations` (`src/verity_portal/audit/router.py`)
- **Setup:** Create violations in the database. Setup users with `ROLE_IT`, `ROLE_ECO`, `ROLE_HR`, and `ROLE_PM`.
- **Action:** Query the violations endpoint with each role.
- **Assertion 1:** `ROLE_IT`, `ROLE_ECO`, and `ROLE_HR` receive 200 OK and get the violation list.
- **Assertion 2:** `ROLE_PM` is blocked with a 403 Forbidden status code.

**Test 5: Violation Resolution Authorization (Backend)**
- **Purpose:** Ensure only authorized personnel (ECO/HR) can resolve access violations, while IT is restricted to read-only views.
- **Test name:** `test_violation_resolution_rbac` 
- **Target Route:** `POST /audit/leaver-mover/violations/{id}/resolve` (`src/verity_portal/audit/router.py`)
- **Setup:** Seed an open violation. Setup users with `ROLE_IT` and `ROLE_ECO`.
- **Action:** Submit a resolution reason payload `{"resolution_reason": "Approved extension"}`.
- **Assertion 1:** `ROLE_IT` receives 403 Forbidden.
- **Assertion 2:** `ROLE_ECO` receives 200 OK, the violation status changes to `RESOLVED`, and `resolution_reason`, `resolved_by`, and `resolved_at` are successfully updated.

---

### FR-8.3: Asynchronous Compliance Alerts
*[Ensures real-time email dispatch is fired upon violation detection.]*

**Test 6: Email Alert on Detection (Backend)**
- **Purpose:** Verify an email alert is sent to security officers when a new violation is discovered.
- **Test name:** `test_violation_triggers_email_alert` 
- **Target Service:** `LeaverMoverReconciliationEngine.run_audit()` (`src/verity_portal/audit/engine.py`)
- **Setup:** Seed a new access violation trigger. Mock the email service wrapper `BaseEmailService`.
- **Action:** Run the audit engine.
- **Assertion 1:** `BaseEmailService.send_alert` is called with details about the new violation.

---

### FR-8.4: Interactive Compliance Dashboard
*[Ensures the tabbed UI displays open/resolved violations and handles resolution flows with proper RBAC restrictions]*

**Test 7: Load Violations and Render Tabs (Frontend)**
- **Purpose:** Verify the dashboard loads all violations and partitions them into open vs. resolved.
- **Test name:** `should create and load violations on init`, `should compute open and resolved violations separately`
- **Target Component:** `AuditDashboardComponent` (`src/app/features/audit/audit-dashboard.component.ts`)
- **Setup:** Mock `AuditService` to return one open and one resolved violation.
- **Action:** Initialize component and detect changes.
- **Assertion 1:** `openViolations` signal contains exactly 1 violation.
- **Assertion 2:** `resolvedViolations` signal contains exactly 1 violation.

**Test 8: Resolve Dialog Flow (Frontend)**
- **Purpose:** Verify the resolution justification modal prompts and captures correct reasons.
- **Test name:** `should handle resolve action and open dialog overlay`, `should submit resolution successfully`
- **Target Component:** `AuditDashboardComponent` (`src/app/features/audit/audit-dashboard.component.ts`)
- **Setup:** Inject mock `AuditService` and trigger resolve action for an open violation.
- **Action:** Input a valid reason and submit.
- **Assertion 1:** `resolveViolation` method is called on the service with the correct ID and reason payload.
- **Assertion 2:** Violation list is reloaded and the modal backdrop closes.

**Test 9: Resolution Input Validation (Frontend)**
- **Purpose:** Enforce a minimum justification length for compliance auditable actions.
- **Test name:** `should block resolution submit if reason is too short`
- **Target Component:** `AuditDashboardComponent` (`src/app/features/audit/audit-dashboard.component.ts`)
- **Setup:** Trigger resolve action for an open violation.
- **Action:** Input an invalid short reason (e.g. less than 5 characters) and submit.
- **Assertion 1:** `resolveViolation` service call is not triggered.
- **Assertion 2:** The dialog remains open for editing.
