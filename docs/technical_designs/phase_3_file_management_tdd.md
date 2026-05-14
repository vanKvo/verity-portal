---
App Version: 1.0.0
---

## Objective
Focus: Resilient File I/O and Metadata Management

## Tech Stack
- **Base Stack:** See [tech_stack.md](tech_stack.md)
- **Module Specific:** `aiofiles` (Async File I/O)

## Project Structure
- `backend/src/verity_portal/intake/service.py` → File metadata management and lifecycle.
- `backend/src/verity_portal/intake/repository.py` → PostgreSQL metadata tracking.
- `backend/src/verity_portal/core/storage/` → Local storage adapters (Staging/Archive).

## Code Style & Standards
- **Asynchronous I/O:** All file operations must use `aiofiles` to prevent blocking the FastAPI event loop.
- **Path Sanitization:** Never use user-provided filenames directly; always use `job_id` UUIDs for storage paths.

## Boundaries
- **Always do:** Validate file size *before* writing to disk.
- **Always do:** Ensure the `verity` schema exists in PostgreSQL before migrations.
- **Never do:** Store physical file content in the database (BLOBs); use the file system for content and DB for metadata.

---

## Requirements

### FR-3.1: Secure File Ingestion & Validation
**Architectural Rationale:** Validating file size at the application edge (FastAPI `File` parameter) protects the infrastructure from resource exhaustion.

#### 3.1.1. Technical Design Specification
- **Max Size:** 50MB (configured in application settings).
- **Extension Check:** Whitelist validation (`.csv`, `.xlsx`).

#### 3.1.2. Implementation Details
- [x] Implemented `FileManager.ingest_file` with size validation.
- [x] Added custom exceptions for `FileTooLargeError` and `UnsupportedFileTypeError`.

#### 3.1.3. Verification Plan
- [x] **Integration Test:** `pytest tests/test_file_management.py`

---

### FR-3.2: Storage Infrastructure (Ports & Adapters)
**Architectural Rationale:** The `StoragePort` decouples the business logic from the physical storage medium, allowing for zero-downtime migration to S3 in the future.

#### 3.2.1. Technical Design Specification
- **Interface:** `StoragePort` with `save`, `get`, `delete`, and `move`.
- **Adapter:** `LocalFileSystemAdapter` using `pathlib` and `aiofiles`.

#### 3.2.2. Implementation Details
- [x] Created `StoragePort` interface.
- [x] Implemented `LocalFileSystemAdapter`.
- [x] Automated directory creation for `/staging` and `/archive`.

#### 3.2.3. Verification Plan
- [x] **Manual Check:** Verify file movement between folders on success.

---

### FR-3.3: Metadata Tracking (Schema Isolation)
**Architectural Rationale:** Moving all portal-specific tables into the `verity` schema avoids collisions with other services sharing the same PostgreSQL cluster.

#### 3.3.1. Technical Design Specification
- **Model:** `FileMetadataModel` with `job_id` (PK), `status`, `original_filename`, and `file_path`.
- **Migration:** Alembic configured with `include_schemas=True`.

#### 3.3.2. Implementation Details
- [x] Defined `FileMetadataModel` in `infrastructure/adapters/database/models.py`.
- [x] Updated Alembic `env.py` to support multi-schema migrations.
- [x] Implemented metadata update logic in `FileManager.archive_file`.

#### 3.3.3. Verification Plan
- [x] **Manual Check:** Verify metadata record creation in PostgreSQL.
