# ADR-007: AWS S3 File Storage Strategy

## Status
Accepted

## Date
2026-05-18

## Context
Originally, ADR-002 established a Local File System Storage approach for ingesting and managing compliance files (CSV/XLSX) to avoid network latency and external dependencies during the MVP phase. However, as the application scales and we move towards a containerized, cloud-native deployment strategy, local file storage presents significant challenges:
- **Statefulness**: Containers become stateful, requiring complex Persistent Volume Claims (PVCs) in orchestration systems like Kubernetes.
- **Scalability**: Local storage limits horizontal scalability, as files uploaded to one application node are not easily accessible by others without distributed file systems (e.g., NFS, EFS).
- **Event-Driven Processing**: We are transitioning to a hybrid data ingestion strategy (ADR-006) that utilizes automated event-driven processing. S3 Event Notifications natively integrate with serverless functions and queueing systems to trigger background worker processes asynchronously.

## Decision
We decided to deprecate the `LocalFileSystemStorage` and adopt AWS S3 as the primary file storage backend (`S3Storage`) for data intake and storage:
1. **Physical Storage**: Implement the `StorageInterface` using an `S3Storage` leveraging the `boto3` library (or `aioboto3` for async I/O). Files will be uploaded to dedicated S3 buckets structured with prefixes like `/staging` and `/archive`.
2. **Metadata Tracking**: The `FileMetadataModel` in the PostgreSQL `verity` schema will remain unchanged, but the physical path will now represent an S3 object key/URI instead of a local file path.
3. **Presigned URLs**: For secure frontend uploads and downloads, the backend will generate pre-signed URLs, allowing clients to interact directly with S3. This completely offloads large file I/O (up to 50MB) from the FastAPI backend, resolving performance bottlenecks.

## Alternatives Considered

### Retaining Local File Storage
- **Pros**: Zero external cloud dependency; no network data transfer costs.
- **Cons**: Forces stateful container deployments; prevents seamless horizontal scaling; requires manual setup of event-driven triggers.
- **Rejected**: Does not align with the modern cloud-native architecture and hybrid ingestion strategy.

### AWS Elastic File System (EFS)
- **Pros**: Provides a shared file system across multiple containers/nodes, requiring minimal changes to the existing local file storage.
- **Cons**: Higher cost than S3; lacks native event notification capabilities compared to S3.
- **Rejected**: S3 provides better scalability, lower costs, and native event integration which is critical for our processing pipelines.

## Consequences
- **Performance**: The FastAPI event loop is entirely freed from handling large file streams by utilizing S3 pre-signed URLs.
- **Scalability**: The application servers become fully stateless, allowing them to be scaled out horizontally without storage constraints.
- **Infrastructure Overhead**: Introduces a dependency on AWS, requiring IAM role configuration, bucket provisioning, and managing network latency.
- **Architectural Shift**: Enables native event-driven workflows (e.g., S3 -> SQS -> S3 Worker) as envisioned in ADR-006.

## Related ADRs
- Supersedes **ADR-002: File Storage Strategy for Data Intake**
- Supports **ADR-006: Hybrid Data Ingestion Strategy**
