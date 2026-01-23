# Service Contract: FileService

**Service**: `FileService`
**Version**: 1.0.0
**Feature**: 001-json-formatter

## Purpose

Handles file I/O operations for JSON documents.

---

## API

### load(url:) -> Result<String, FileError

Loads file content from disk.

**Input**:
- `url: URL` - File URL to load

**Output**:
- `Result<String, FileError>`
  - Success: File contents as String
  - Failure: `FileError`

**FileError Types**:

| Error | Condition |
|-------|-----------|
| notFound | File does not exist |
| permissionDenied | No read access |
| encodingError | Cannot decode as UTF-8 |
| tooLarge | File exceeds size limit (10MB) |
| networkDrive | Network path not supported |

**Performance**: Expected < 500ms for 10MB file from SSD

---

### save(_:url:) -> Result<Void, FileError>

Writes string content to file.

**Input**:
- `content: String` - Content to write
- `url: URL` - Destination file URL

**Output**:
- `Result<Void, FileError>`

**FileError Types**:

| Error | Condition |
|-------|-----------|
| permissionDenied | No write access |
| diskFull | Insufficient space |
| invalidPath | Malformed URL |
| networkDrive | Network path not supported |

---

### validate(url:) -> Bool

Checks if URL is valid for JSON operations.

**Input**:
- `url: URL` - URL to validate

**Output**:
- `Bool` - true if safe to use

**Validation Checks**:
1. URL is file:// scheme
2. File exists (for load operations)
3. Parent directory exists (for save operations)
4. Not a network path
5. Size within limits (for load)

---

### file_size(url:) -> Result<Int, FileError>

Gets file size in bytes.

**Input**:
- `url: URL` - File URL

**Output**:
- `Result<Int, FileError>` - Size in bytes or error

**Use Case**: Pre-check size before loading large files
