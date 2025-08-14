# Comprehensive Logging System Documentation

## Overview

This backend implements a comprehensive logging system with the following key features:

- **Separate Request and Application Logs**: Clear separation between HTTP request logs and custom application logs
- **Sensitive Data Filtering**: Automatic filtering of sensitive information like passwords, tokens, API keys, etc.
- **Multiple Status Code Logging**: Logs all HTTP status codes (200, 400, 401, 403, 404, 500, etc.)
- **Daily Log Rotation**: Automatic daily rotation with configurable retention periods
- **Security Audit Trail**: Separate security logging for audit purposes
- **Structured JSON Logging**: Consistent JSON format for easy parsing and analysis

## Log File Structure

The logging system creates the following log files in the `logs/` directory:

### Request Logs

- `requests-current.log` → `requests-YYYY-MM-DD.log` - All HTTP requests
- `requests-errors-current.log` → `requests-errors-YYYY-MM-DD.log` - Only 4xx/5xx request errors

### Application Logs

- `app-current.log` → `app-YYYY-MM-DD.log` - General application logs
- `app-debug-current.log` → `app-debug-YYYY-MM-DD.log` - Debug logs (dev only)
- `app-errors-current.log` → `app-errors-YYYY-MM-DD.log` - Application error logs

### Security Logs

- `security-current.log` → `security-YYYY-MM-DD.log` - Security events and audit trail

## Sensitive Data Filtering

The following fields are automatically filtered and replaced with `[FILTERED]`:

- `password`, `pass`, `pwd`
- `secret`, `token`, `accessToken`, `refreshToken`
- `authorization`, `auth`, `apikey`, `api_key`
- `username`, `email` (as requested)
- `creditCard`, `ssn`, `socialSecurityNumber`
- `pin`, `cvv`, `cvc`

## Sample APIs for Testing

### 1. `/api/user/information`

Returns user information with sensitive data filtered from logs.

**Example Request:**

```bash
curl "http://localhost:3000/api/user/information?userId=1"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "role": "user"
  },
  "requestId": "req_1234567890_abcdef",
  "processingTime": "112ms"
}
```

**What gets logged:**

- Request logs: Full HTTP request details
- Application logs: User data with password/apiKey showing as `[FILTERED]`

### 2. `/api/user/socials`

Returns user social connections with access tokens filtered from logs.

**Example Request:**

```bash
curl "http://localhost:3000/api/user/socials?userId=1"
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "platform": "github",
      "username": "john_doe_dev",
      "profileUrl": "https://github.com/john_doe_dev",
      "isPublic": true
    }
  ],
  "requestId": "req_1234567890_abcdef"
}
```

**What gets logged:**

- Request logs: HTTP request details
- Application logs: Social data with accessToken/refreshToken showing as `[FILTERED]`

### 3. `/api/user/error` - Error Testing Endpoint

Triggers various error types for testing error logging.

**Error Types:**

```bash
# 500 Server Error (default)
curl "http://localhost:3000/api/user/error"
curl "http://localhost:3000/api/user/error?type=server"

# 400 Validation Error
curl "http://localhost:3000/api/user/error?type=validation"

# 401 Unauthorized
curl "http://localhost:3000/api/user/error?type=unauthorized"

# 403 Forbidden
curl "http://localhost:3000/api/user/error?type=forbidden"

# 404 Not Found
curl "http://localhost:3000/api/user/error?type=notfound"
```

**What gets logged:**

- Request logs: Error responses with appropriate status codes
- Application logs: Error details with sensitive data filtered
- Security logs: Security-related errors (401, 403, 429)

## How to Use the Logger in Your Code

### Import the Logger

```typescript
import { logger } from "../utils/logger";
```

### Request Logging (Automatic)

Request logging is handled automatically by the `requestLogger` middleware. It logs:

- Request start with method, URL, headers (filtered), IP, etc.
- Request completion with status code, duration, response size
- Different log levels based on status codes:
  - `INFO` for 2xx responses
  - `WARN` for 4xx responses
  - `ERROR` for 5xx responses

### Custom Application Logging

```typescript
// Info level logging
logger.app.info("User operation completed", {
  userId: 123,
  operation: "profile_update",
  duration: "45ms",
});

// Debug level logging (development only)
logger.app.debug("Processing user data", {
  userData: userObject, // Sensitive fields will be filtered
});

// Warning level logging
logger.app.warn("Slow database query detected", {
  query: "SELECT * FROM users",
  duration: "2.5s",
  threshold: "1s",
});

// Error level logging
logger.app.error("Failed to process payment", {
  error: error.message,
  stack: error.stack,
  paymentData: paymentObject, // Sensitive fields will be filtered
});
```

### Security Logging

```typescript
// Security events
logger.security.info("User login successful", {
  userId: 123,
  ip: req.ip,
  userAgent: req.get("User-Agent"),
});

logger.security.warn("Multiple failed login attempts", {
  ip: req.ip,
  attempts: 5,
  timeWindow: "5min",
});

logger.security.error("Potential security breach detected", {
  type: "sql_injection_attempt",
  ip: req.ip,
  payload: suspiciousInput,
});
```

## Log Format

All logs use structured JSON format:

```json
{
  "timestamp": "2025-08-14 10:37:12.977",
  "level": "INFO",
  "service": "banv-backend-app",
  "message": "User information retrieved successfully",
  "requestId": "req_1755142632859_umabybluy",
  "userId": 1,
  "processingTime": "112ms",
  "endpoint": "getUserInformation",
  "userData": {
    "id": 1,
    "username": "[FILTERED]",
    "email": "[FILTERED]",
    "password": "[FILTERED]",
    "apiKey": "[FILTERED]",
    "firstName": "John"
  }
}
```

## Log Levels

### Request Logs

- `INFO`: Successful requests (2xx status codes)
- `WARN`: Client errors (4xx status codes)
- `ERROR`: Server errors (5xx status codes)

### Application Logs

- `DEBUG`: Detailed debugging info (development only)
- `INFO`: General application events
- `WARN`: Warning conditions
- `ERROR`: Error conditions

### Security Logs

- `INFO`: Security events (logins, access grants)
- `WARN`: Security warnings (failed attempts, suspicious activity)
- `ERROR`: Security incidents (breaches, attacks)

## Log Retention

- **Request logs**: 30 days
- **Application logs**: 30 days
- **Debug logs**: 7 days (development only)
- **Error logs**: 60 days
- **Security logs**: 90 days
- **Max file size**: 50MB (20MB for debug logs)

## Testing the Logging System

1. **Start the server:**

```bash
npm run dev
```

2. **Test successful requests:**

```bash
curl "http://localhost:3000/api/user/information"
curl "http://localhost:3000/api/user/socials?userId=1"
```

3. **Test error conditions:**

```bash
curl "http://localhost:3000/api/user/error?type=server"      # 500 error
curl "http://localhost:3000/api/user/error?type=unauthorized" # 401 error
curl "http://localhost:3000/api/nonexistent"                # 404 error
```

4. **Check log files:**

```bash
ls -la logs/
tail -f logs/requests-current.log    # Request logs
tail -f logs/app-current.log         # Application logs
tail -f logs/security-current.log    # Security logs
```

## Key Features Demonstrated

✅ **Separate Request/Custom Logs**: Request logs in `requests-*.log`, application logs in `app-*.log`

✅ **Sensitive Data Filtering**: Passwords, tokens, API keys show as `[FILTERED]` in logs

✅ **All Status Codes Logged**: 200, 400, 401, 403, 404, 500 all properly logged with appropriate levels

✅ **Issue Tracking**: Each request has a unique `requestId` for easy correlation across logs

✅ **Performance Monitoring**: Request duration, slow request detection, performance categorization

✅ **Security Auditing**: Separate security log with unauthorized access attempts, failed logins, etc.

## Configuration

The logging system can be configured via environment variables:

- `NODE_ENV`: Controls log levels (production vs development)
- Log file paths and retention can be modified in `/src/utils/logger.ts`
- Sensitive field list can be extended in the `SENSITIVE_FIELDS` array

This comprehensive logging system provides excellent observability for debugging issues, tracking performance, monitoring security events, and maintaining compliance with data protection requirements.
