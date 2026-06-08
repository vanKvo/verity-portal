# Technical Design Document: Phase 7 - IT Asset & PO Audit

## 1. System Architecture

### Tech Stack
- **Base Stack:** See [tech_stack.md](../technical_designs/tech_stack.md)
- **Module Specific:** No new external libraries introduced. Reuses the `boto3` integration and `pandas` capabilities established in Phase 6.

### Project Structure
- `src/verity_portal/data_hub/procurement/` → Contains models, schemas, and services for financial PO master data.
- `src/verity_portal/data_hub/inventory/` → Contains models, schemas, and services for physical IT Asset master data.
- `src/verity_portal/data_hub/audit/` → Contains the reconciliation engine business logic and anomaly tracking models.

### Boundaries
- **Always do:** Rely on the `DataHubOrchestrationService` to invoke sub-services.
- **Never do:** Write database commits or direct S3 client logic inside the FastAPI `router.py` layer.

---

## 2. Global Technical Context (The Contracts)

### Data Model & Storage
- **ProcurementModel:** Stores PO data. Schema includes `po_number` (String, Index), `description` (String),`purchase_date` (DateTime), `vendor` (String),`asset_category` (String), `quantity` (Integer), `unit_price` (Float), `total_cost` (Float), `status` (String).
- **InventoryModel:** Stores physical asset data. Schema includes `asset_tag` (String, Primary Key), `po_number` (String, Foreign Key mapping, required), `serial_number` (String), assigned_employee_id (String, Foreign Key mapping to Personnel table, nullable),`status` (Enum: IN_USE, RETIRED, LOST).
- **AssetViolationModel:** Stores discrepancies. Schema includes `violation_type` (Enum: GHOST_ASSET, WASTED_SPEND), `asset_tag`, `po_number`, `status` (Enum: OPEN, RESOLVED), `resolution_reason` (String).

### API Specifications & Security (RBAC)
- `POST /data-hub/procurement/upload` (Requires: `ROLE_FINANCE`): Manual file upload endpoint.
- `POST /data-hub/inventory/upload` (Requires: `ROLE_IT`): Manual file upload endpoint.
- `POST /data-hub/webhooks/s3-ingest` (Requires: valid webhook token): Triggers background ingestion.
- `GET /data-hub/audit/violations` (Requires: `ROLE_FINANCE` or `ROLE_IT`): Fetches paginated discrepancies.
- `POST /data-hub/audit/violations/{id}/resolve` (Requires: `ROLE_FINANCE`): Resolves a financial anomaly.

### Event Interfaces (Asynchronous)
- **Subscribes To:** AWS EventBridge S3 `ObjectCreated` events.
- **Publishes:** Email/in-app notifications for `GHOST_ASSET` (to IT) and `WASTED_SPEND` (to Finance) upon completion of the reconciliation audit.

### Environment Variables & Configuration
- `S3_PROCUREMENT_BUCKET_NAME`: Bucket for incoming financial exports.
- `S3_INVENTORY_BUCKET_NAME`: Bucket for incoming ITAM exports.

### Error Handling Strategy
- Raise `IngestionRoutingError` mapped to `400 Bad Request` if a file key lacks required keywords.
- Raise `AuthorizationError` mapped to `403 Forbidden` if an IT user attempts to resolve a financial violation.

---

## 3. Feature Implementation Breakdown

### Requirement ID: FR-7.1 - Procurement & Inventory Master Data Hub
**Architectural Rationale:** Extending the Hybrid Data Hub pattern to maintain a centralized system of record for financial and physical hardware assets.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** Expand `router.py` with `/procurement/upload` and `/inventory/upload` endpoints.
- **Service Layer:** Update `DataHubOrchestrationService` to handle dynamic routing for `procurement`, `finance`, `inventory`, and `asset` file keywords.
- **Data Access:** Extend the `MasterDataIngestor` engine to perform transactional UPSERTs for both new models.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** Add "Procurement Records" and "IT Inventory" tabs to the `DataHubComponent`. Remove automatic status polling and instead rely on manual page reloads for the `updated_at` sync status to prevent unnecessary network latency.
- **State & Service:** Reuse the `SharedMapperComponent` to pass dynamic JSON column configurations to the backend.

#### Implementation Tasks
- [ ] **[Backend]** Implement SQLAlchemy models and Pydantic schemas for Procurement and Inventory.
- [ ] **[Backend]** Expand `DataHubOrchestrationService.handle_s3_event` to route new keywords.
- [ ] **[Frontend]** Implement UI tabs and manual reload buttons in `DataHubComponent`.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Routing successfully parses keywords and schedules background tasks.
- [ ] **[Frontend]** Component Test: `DataHubComponent` renders new tabs restricted by proper roles.

---

### Requirement ID: FR-7.2 - Asset Reconciliation Engine
**Architectural Rationale:** Offloading heavy cross-referencing logic to a dedicated business engine prevents polluting the ingestion flow and allows scheduled independent audits.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** Implement `/audit/violations` and `/audit/violations/{id}/resolve`.
- **Service Layer:** Create `AssetReconciliationEngine` to compare `ProcurementModel` against `InventoryModel` using optimized SQL joins.
- **Data Access:** Execute queries identifying `IN_USE` Inventory without matching POs (Ghost Assets) and active PO maintenance for `RETIRED` Inventory (Wasted Spend).

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** Build the `AssetAuditDashboardComponent` featuring a data grid of anomalies.
- **State & Service:** Render a "Resolve" modal exclusively for `ROLE_FINANCE` users. Hide this action for `ROLE_IT` users.

#### Implementation Tasks
- [ ] **[Backend]** Build the `AssetReconciliationEngine` cross-reference query logic.
- [ ] **[Backend]** Implement targeted notification dispatching (`ROLE_FINANCE` vs `ROLE_IT`).
- [ ] **[Frontend]** Build the `AssetAuditDashboardComponent`.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Ghost Assets are successfully identified and stored in the violations table.
- [ ] **[Frontend]** Component Test: Resolve action button is disabled/hidden for `ROLE_IT`.
