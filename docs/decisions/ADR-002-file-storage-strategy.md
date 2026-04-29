# ADR-002: File Storage Strategy for Data Intake

## Status
Accepted

## Date
2026-04-28

## Context
The Verity Portal requires a mechanism to ingest and manage potentially large compliance files (CSV/XLSX) uploaded by users. 
Key requirements:
- Files can be up to 50MB in size.
- Need to prevent the FastAPI backend from blocking during large file I/O operations.
- Require tracking the lifecycle of a file (e.g., Staged, Processed, Archived) for audit purposes.
- Must align with the enterprise database schema pattern (using the `verity` schema in PostgreSQL).
- Must follow Hexagonal Architecture principles to allow future swapping of storage backends (e.g., migrating from Local Disk to AWS S3).

## Decision
We decided to implement a dual-storage approach using an asynchronous local file system adapter and a PostgreSQL metadata table:
1.  **Physical Storage (Hexagonal Port & Adapter)**: Define a `StoragePort` interface and implement a `LocalFileSystemAdapter` using `aiofiles`. This allows asynchronous non-blocking file I/O on the local disk, organized into `/staging` and `/archive` directories.
2.  **Metadata Tracking**: Create a `FileMetadataModel` within the `verity` PostgreSQL schema to track the file's UUID, original name, physical path, and processing `status`.
3.  **Domain Orchestration**: The `FileManager` domain service coordinates these two layers, ensuring that files are saved to disk *before* their metadata is committed to the database, enforcing the 50MB upload limit, and generating secure UUID-based filenames to prevent directory traversal attacks.

## Alternatives Considered

### Direct Database Storage (BLOB/BYTEA)
- **Pros**: Simplifies architecture; transactional consistency between file and metadata.
- **Cons**: Significantly bloats the database size; negatively impacts database backup/restore performance; inefficient for processing large analytical files via Pandas.
- **Rejected**: Database should be reserved for structured data, not 50MB raw file dumps.

### Immediate Cloud Storage (AWS S3)
- **Pros**: Highly scalable, offloads disk management.
- **Cons**: Introduces cloud dependency and network latency during the initial MVP development phase.
- **Rejected**: While a valid future path, a `LocalFileSystemAdapter` is sufficient for current requirements. The `StoragePort` interface ensures we can seamlessly swap to an `S3Adapter` later without changing domain logic.

## Consequences
- **Performance**: Asynchronous file I/O (`aiofiles`) keeps the FastAPI event loop unblocked, ensuring high concurrency.
- **Security**: UUID-based filenames mitigate injection attacks, and the strict 50MB limit prevents denial-of-service via disk exhaustion.
- **Maintainability**: The clear separation between the `StoragePort` and `FileMetadataModel` adheres perfectly to the Hexagonal Architecture, making future cloud migrations trivial.
