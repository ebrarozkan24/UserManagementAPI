# TechHive User Management API

A RESTful User Management API built with ASP.NET Core (.NET 8) minimal APIs for TechHive Solutions' HR and IT teams. It supports full CRUD operations on user records, input validation, and a three-stage middleware pipeline for error handling, token authentication and request logging. Data is kept in memory (it resets when the app restarts).

## Requirements

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

## Run

```bash
dotnet run
```

The API listens on `http://localhost:5080`.

## Authentication

Every endpoint under `/api` requires a bearer token:

```
Authorization: Bearer techhive-secret-token
```

Valid tokens are configured in `appsettings.json` under `Auth:Tokens`. Replace the sample token before using this anywhere real. `GET /` and `GET /health` are public.

## Endpoints

| Method | Route | Description | Success | Errors |
|--------|-------|-------------|---------|--------|
| GET | `/api/users` | List users. Optional query: `department`, `page` (default 1), `pageSize` (default 20, max 100). Total count is returned in the `X-Total-Count` header. | 200 | 400, 401 |
| GET | `/api/users/{id}` | Get one user | 200 | 401, 404 |
| POST | `/api/users` | Create a user | 201 | 400, 401, 409 |
| PUT | `/api/users/{id}` | Update a user | 200 | 400, 401, 404, 409 |
| DELETE | `/api/users/{id}` | Delete a user | 204 | 401, 404 |
| GET | `/api/test-error` | Throws on purpose to demonstrate the error-handling middleware | 500 | 401 |

### User body (POST / PUT)

```json
{
  "firstName": "Can",
  "lastName": "Ozturk",
  "email": "can.ozturk@techhive.com",
  "department": "Finance",
  "jobTitle": "Accountant"
}
```

Validation rules: all fields are required; names, department and job title need 2-50 (job title 2-80) characters; email must be a valid address (max 100) and unique (case-insensitive). Validation failures return `400` with a per-field error list; duplicate emails return `409`.

## Middleware pipeline

Registered in `Program.cs` in this order:

1. **ErrorHandlingMiddleware** - catches unhandled exceptions and returns a consistent JSON error (`500`), or `400` for malformed request bodies.
2. **TokenAuthenticationMiddleware** - rejects requests without a valid bearer token with `401`.
3. **RequestLoggingMiddleware** - logs the HTTP method, request path, response status code and duration of each request.

## Testing

Use `UserManagementAPI.http` (VS Code REST Client extension or Visual Studio), or start the API and run the automated smoke test (needs `bash` and `curl`):

```bash
bash smoke-test.sh
```

## Project structure

```
Program.cs                      Endpoints and middleware pipeline
Models/                         User and UserRequest (with validation attributes)
Services/                       IUserService and in-memory UserService
Validation/ModelValidator.cs    DataAnnotations validation helper
Middleware/                     Error handling, authentication, logging
```
