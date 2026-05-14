# Test-Driven Development Spec: Phase 3 (File Management Service)

Following the **Test-Driven Development (TDD)** guidelines, the developer must start by writing these failing tests before implementing the Phase 3 functionality. The tests are designed to follow the Arrange-Act-Assert pattern, ensuring state-based verification rather than purely interaction-based.

## 1. Backend Unit Tests: Core Business Logic
**Location:** `backend/tests/domain/services/test_file_manager.py`
**Type:** Small / Fast (Milliseconds)
**Mocking Strategy:** Use a `FakeStorageAdapter` (in-memory) instead of a mocking framework to verify state.

### Tests to Write:
- `test_save_file_orchestrates_storage_and_metadata()`: 
  - **Arrange:** Initialize `FileManager` with `FakeStorageAdapter` and an in-memory test database.
  - **Act:** Call `file_manager.ingest_file(file_content, filename)`.
  - **Assert:** Verify the file content exists in `FakeStorageAdapter`. Verify a corresponding record exists in the database `file_metadata` table with status `STAGED`.
- `test_rejects_files_over_50mb()`:
  - **Arrange:** Create a dummy byte payload slightly over 50MB.
  - **Act/Assert:** Expect a `ValueError` or specific `FileSizeLimitExceededError` when calling `file_manager.ingest_file()`.
- `test_rejects_invalid_file_extensions()`:
  - **Arrange:** Pass a filename ending in `.exe` or `.txt`.
  - **Act/Assert:** Expect an `InvalidFileFormatError`.
- `test_archive_file_moves_storage_and_updates_status()`:
  - **Arrange:** Stage a file.
  - **Act:** Call `file_manager.archive_file(job_id)`.
  - **Assert:** Verify the database status changes to `ARCHIVED`. Verify the `FakeStorageAdapter` confirms the file path moved from `/staging` to `/archive`.

## 2. Backend Integration Tests: Infrastructure Adapters
**Location:** `backend/tests/infrastructure/adapters/storage/test_local_adapter.py`
**Type:** Medium (Seconds)
**Constraints:** Uses actual local filesystem read/writes in a temporary pytest directory (`pytest's tmp_path`).

### Tests to Write:
- `test_local_adapter_saves_file_to_disk(tmp_path)`:
  - **Act:** Save a byte string using the adapter pointing to `tmp_path`.
  - **Assert:** Use Python's `os.path.exists()` to verify the file was actually written to the physical disk.
- `test_local_adapter_moves_file_to_archive(tmp_path)`:
  - **Act:** Use the adapter to move a staged file to an archive directory.
  - **Assert:** Verify the file no longer exists in staging but does exist in the archive directory.

## 3. Database Migration Tests
**Location:** `backend/tests/infrastructure/adapters/test_database_models.py`
**Type:** Medium (Seconds)

### Tests to Write:
- `test_file_metadata_schema_enforces_constraints()`:
  - **Act/Assert:** Attempt to insert a record into `file_metadata` without a `job_id` or `status` and verify it raises a SQLAlchemy IntegrityError.
  
## Implementation Checklist for Developer
1. Create `test_file_manager.py` -> See it fail.
2. Implement `file_manager.py` logic -> See it pass.
3. Create `test_local_adapter.py` -> See it fail.
4. Implement `LocalFileSystemAdapter` -> See it pass.
5. Create migration tests -> See them fail.
6. Generate Alembic migration for `file_metadata` -> See tests pass.
