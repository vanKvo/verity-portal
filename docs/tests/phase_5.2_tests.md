# Phase 5.2: File Upload Dropbox - Test Specification

## Objective
Ensure the file upload interactions (drag-and-drop, HTTP upload lifecycle) function correctly and fail gracefully when invalid files are provided. Furthermore, verify that the integration between the new upload component, the workflow dashboard, and the data mapper works seamlessly. Developers must use Test-Driven Development (TDD).

---

## Incremental Test Plan by Problem Category

### Problem 1: Manual Job ID Entry is Not Production-Ready
*Ensuring the standalone upload component accurately handles UI interactions and API requests.*

**Test 1: Component Instantiation (Frontend)**
- **Purpose:** Verifies that the component can be created without throwing errors.
- **Test name:** `should create the component`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component.
- **Action:** None.
- **Assertion 1:** Verify the component is created successfully.

**Test 2: Click Delegation (Frontend)**
- **Purpose:** Ensures that clicking the visual dropzone effectively opens the browser's native file picker.
- **Test name:** `should trigger native file input click when dropzone is clicked`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component and spy on the native file input's `click` method.
- **Action:** Click the visual dropzone area.
- **Assertion 1:** Verify the native file input's `click` method was called.

**Test 3: Drag and Drop Styling State (Frontend)**
- **Purpose:** Verifies the visual feedback mechanisms for drag-and-drop interactions.
- **Test name:** `should handle dragover and dragleave events to toggle isDragging state`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component.
- **Action:** Trigger a `dragover` event on the host element.
- **Assertion 1:** Verify the internal `isDragging` signal is true.
- **Action:** Trigger a `dragleave` event on the host element.
- **Assertion 2:** Verify the internal `isDragging` signal is false.

**Test 4: Drag and Drop File Capture (Frontend)**
- **Purpose:** Verifies that a dropped file is captured and the default browser behavior (opening the file) is prevented.
- **Test name:** `should handle file drop event, prevent default behavior, and trigger upload`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component. Mock a `drop` event containing a valid File object.
- **Action:** Trigger the `drop` event.
- **Assertion 1:** Verify `event.preventDefault()` was called.
- **Assertion 2:** Verify the internal upload logic was triggered with the mocked file.

**Test 5: Invalid File Extension Rejection (Frontend)**
- **Purpose:** Ensures the frontend immediately rejects unsupported file types before attempting an upload.
- **Test name:** `should prevent upload and set errorMessage if file extension is invalid`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component with `@Input() allowedExtensions = ['.csv']`.
- **Action:** Attempt to upload a file named `malicious.exe`.
- **Assertion 1:** Verify the upload HTTP request is NOT called.
- **Assertion 2:** Verify the `errorMessage` signal is populated with a relevant error.

**Test 6: Successful HTTP Upload and Event Emission (Frontend)**
- **Purpose:** Verifies the end-to-end happy path of constructing the payload, making the request, and emitting the parsed backend response.
- **Test name:** `should upload file and emit onUploadSuccess upon successful HTTP response`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component, spy on the `onUploadSuccess` event emitter, and mock the `HttpClient`.
- **Action:** Upload a valid CSV file. Flush a successful JSON response from the mocked HTTP backend.
- **Assertion 1:** Verify the HTTP POST request was made to `/intake/upload` with a generated UUID.
- **Assertion 2:** Verify `onUploadSuccess.emit()` was called with the exact data returned by the mocked backend.

**Test 7: Progress Feedback (Frontend)**
- **Purpose:** Verifies the UI indicates active upload progress to the user.
- **Test name:** `should display MatProgressSpinner while uploading`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component. Set `isUploading` to true.
- **Action:** Trigger change detection.
- **Assertion 1:** Verify `mat-spinner` is present in the DOM.

**Test 8: Error Feedback (Frontend)**
- **Purpose:** Verifies the UI displays error messages when an upload fails.
- **Test name:** `should emit onUploadError and set errorMessage if HTTP request fails`
- **Target Component:** `FileUploadComponent` (`file-upload.component.spec.ts`)
- **Setup:** Mount the component. Mock a failed HTTP response.
- **Action:** Trigger upload and flush error.
- **Assertion 1:** Verify `errorMessage` is set and `onUploadError` is emitted.

---

### Problem 3: Component Reusability vs. Monolith
*Ensuring the workflow dashboard correctly orchestrates the File Upload and Mapper components.*

**Test 9: Stepper Initial State (Frontend)**
- **Purpose:** Verifies the default view of the workflow asks the user to upload a file rather than jumping straight to mapping.
- **Test name:** `should display FileUploadComponent initially for Step 1 (HR Records)`
- **Target Component:** `AuditDashboardComponent` (`audit-dashboard.component.spec.ts`)
- **Setup:** Mount the component.
- **Action:** View Step 1.
- **Assertion 1:** Verify the `FileUploadComponent` is visible.
- **Assertion 2:** Verify the `SharedMapperComponent` is hidden.

**Test 10: Successful HR Upload Orchestration (Frontend)**
- **Purpose:** Verifies the dashboard seamlessly transitions from the upload view to the mapping view upon receiving HR data.
- **Test name:** `should hide FileUploadComponent for HR record and show SharedMapperComponent upon successful upload event`
- **Target Component:** `AuditDashboardComponent` (`audit-dashboard.component.spec.ts`)
- **Setup:** Mount the component.
- **Action:** Manually trigger the `onUploadSuccess` event from the Step 1 `FileUploadComponent` with mock data.
- **Assertion 1:** Verify the dashboard's internal state (e.g., `hrJobId`, `hrHeaders`) is updated with the mock data.
- **Assertion 2:** Verify only Step 2's upload component remains visible.
- **Assertion 3:** Verify the `SharedMapperComponent` for HR becomes visible.

**Test 11: Successful IT Upload Orchestration (Frontend)**
- **Purpose:** Verifies the dashboard seamlessly transitions from the upload view to the mapping view upon receiving IT data.
- **Test name:** `should hide FileUploadComponent for IT record and show SharedMapperComponent upon successful upload event`
- **Target Component:** `AuditDashboardComponent` (`audit-dashboard.component.spec.ts`)
- **Setup:** Mount the component.
- **Action:** Manually trigger the `onUploadSuccess` event from the Step 2 `FileUploadComponent` with mock data.
- **Assertion 1:** Verify the dashboard's internal state (e.g., `itJobId`, `itHeaders`) is updated with the mock data.
- **Assertion 2:** Verify Step 2's upload component becomes hidden.
- **Assertion 3:** Verify the `SharedMapperComponent` for IT becomes visible.

**Test 12: Passing Data to Mapper (Frontend)**
- **Purpose:** Verifies the architectural change that allows the generic mapper to receive data externally rather than fetching it itself.
- **Test name:** `should accept headers and suggestions as inputs instead of internal signals`
- **Target Component:** `SharedMapperComponent` (`shared-mapper.component.spec.ts`)
- **Setup:** Mount the component and provide mock data via the new `@Input()` or `input()` signals for `headers` and `suggestions`.
- **Action:** Trigger change detection.
- **Assertion 1:** Verify the UI dropdowns render the provided `headers`.
- **Assertion 2:** Verify the autofill logic successfully uses the provided `suggestions`.
