using UserManagementAPI.Middleware;
using UserManagementAPI.Models;
using UserManagementAPI.Services;
using UserManagementAPI.Validation;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IUserService, UserService>();

var app = builder.Build();

// Middleware pipeline. Order matters:
//   1. Error handling  - outermost, so it catches exceptions from everything below.
//   2. Authentication  - rejects requests without a valid token before they reach the endpoints.
//   3. Logging         - logs the requests that were allowed through, with their final status code.
app.UseMiddleware<ErrorHandlingMiddleware>();
app.UseMiddleware<TokenAuthenticationMiddleware>();
app.UseMiddleware<RequestLoggingMiddleware>();

// ---- Public endpoints (no token needed) ----
app.MapGet("/", () => Results.Ok(new { name = "TechHive User Management API", status = "running" }));
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

// ---- Demo endpoint: throws on purpose so the error-handling middleware can be verified ----
app.MapGet("/api/test-error", () =>
{
    throw new InvalidOperationException("Intentional test exception.");
});

// ---- User CRUD endpoints (token required) ----
var users = app.MapGroup("/api/users");

// GET /api/users?department=IT&page=1&pageSize=20
users.MapGet("/", (HttpContext http, IUserService service, string? department, int? page, int? pageSize) =>
{
    var currentPage = page ?? 1;
    var size = pageSize ?? 20;

    if (currentPage < 1 || size < 1 || size > 100)
    {
        return Results.BadRequest(new { error = "page must be >= 1 and pageSize must be between 1 and 100." });
    }

    var (items, total) = service.GetAll(department, currentPage, size);
    http.Response.Headers["X-Total-Count"] = total.ToString();
    return Results.Ok(items);
});

// GET /api/users/{id}
users.MapGet("/{id:int}", (int id, IUserService service) =>
{
    var user = service.GetById(id);
    return user is null
        ? Results.NotFound(new { error = $"User with id {id} was not found." })
        : Results.Ok(user);
});

// POST /api/users
users.MapPost("/", (UserRequest request, IUserService service) =>
{
    if (!ModelValidator.TryValidate(request, out var errors))
    {
        return Results.ValidationProblem(errors);
    }

    var (result, user) = service.Create(request);
    return result switch
    {
        ServiceResult.DuplicateEmail => Results.Conflict(new { error = "A user with this email already exists." }),
        _ => Results.Created($"/api/users/{user!.Id}", user)
    };
});

// PUT /api/users/{id}
users.MapPut("/{id:int}", (int id, UserRequest request, IUserService service) =>
{
    if (!ModelValidator.TryValidate(request, out var errors))
    {
        return Results.ValidationProblem(errors);
    }

    var (result, user) = service.Update(id, request);
    return result switch
    {
        ServiceResult.NotFound => Results.NotFound(new { error = $"User with id {id} was not found." }),
        ServiceResult.DuplicateEmail => Results.Conflict(new { error = "A user with this email already exists." }),
        _ => Results.Ok(user)
    };
});

// DELETE /api/users/{id}
users.MapDelete("/{id:int}", (int id, IUserService service) =>
    service.Delete(id)
        ? Results.NoContent()
        : Results.NotFound(new { error = $"User with id {id} was not found." }));

app.Run();
