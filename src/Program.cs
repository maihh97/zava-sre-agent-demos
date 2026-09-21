using Microsoft.Data.SqlClient;
using System.Text.RegularExpressions;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddApplicationInsightsTelemetry();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// GET / — welcome page
app.MapGet("/", () => Results.Ok(new
{
    app = "Zava",
    version = "1.0.0",
    message = "Welcome to Zava — Intelligent Athletic Apparel"
}));

// GET /health — checks SQL database connectivity
app.MapGet("/health", async (IConfiguration config) =>
{
    var connectionString = config.GetConnectionString("DefaultConnection");
    if (string.IsNullOrEmpty(connectionString))
    {
        return Results.Json(new { status = "unhealthy", database = "connection_failed", error = "Connection string is not configured" },
            statusCode: 503);
    }

    try
    {
        using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT 1";
        await command.ExecuteScalarAsync();

        return Results.Ok(new { status = "healthy", database = "connected" });
    }
    catch (Exception ex)
    {
        return Results.Json(new { status = "unhealthy", database = "connection_failed", error = ex.Message },
            statusCode: 503);
    }
});

// GET /api/products — list products, optionally filtered by category
app.MapGet("/api/products", async (IConfiguration config, string? category) =>
{
    var connectionString = config.GetConnectionString("DefaultConnection");
    if (string.IsNullOrEmpty(connectionString))
    {
        return Results.Problem("Database connection string is not configured", statusCode: 500);
    }

    try
    {
        var products = new List<Product>();
        using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        using var command = connection.CreateCommand();

        if (!string.IsNullOrEmpty(category))
        {
            command.CommandText = "SELECT Id, Name, Price, Category FROM Products WHERE Category = @Category";
            command.Parameters.AddWithValue("@Category", category);
        }
        else
        {
            command.CommandText = "SELECT TOP 100 Id, Name, Price, Category FROM Products";
        }

        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            products.Add(new Product(
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetDecimal(2),
                reader.GetString(3)));
        }

        return Results.Ok(products);
    }
    catch (Exception ex)
    {
        return Results.Problem($"Failed to retrieve products: {ex.Message}", statusCode: 500);
    }
})
.WithName("GetProducts")
.WithOpenApi();

// GET /api/products/{id} — get a single product by ID
app.MapGet("/api/products/{id:int}", async (int id, IConfiguration config) =>
{
    var connectionString = config.GetConnectionString("DefaultConnection");
    if (string.IsNullOrEmpty(connectionString))
    {
        return Results.Problem("Database connection string is not configured", statusCode: 500);
    }

    try
    {
        using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT Id, Name, Price, Category FROM Products WHERE Id = @Id";
        command.Parameters.AddWithValue("@Id", id);

        using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var product = new Product(
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetDecimal(2),
                reader.GetString(3));
            return Results.Ok(product);
        }

        return Results.NotFound(new { error = $"Product with ID {id} not found" });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Failed to retrieve product: {ex.Message}", statusCode: 500);
    }
})
.WithName("GetProductById")
.WithOpenApi();

app.Lifetime.ApplicationStarted.Register(() =>
    _ = Task.Run(() => InitializeDatabaseAsync(app.Configuration, app.Logger)));
app.Run();

static async Task InitializeDatabaseAsync(IConfiguration configuration, ILogger logger)
{
    var connectionString = configuration.GetConnectionString("DefaultConnection");
    var seedPath = Path.Combine(AppContext.BaseDirectory, "seed-database.sql");
    if (string.IsNullOrWhiteSpace(connectionString) || !File.Exists(seedPath))
    {
        logger.LogWarning("Database initialization skipped because configuration or seed file is missing");
        return;
    }

    for (var attempt = 1; attempt <= 12; attempt++)
    {
        try
        {
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            var sql = await File.ReadAllTextAsync(seedPath);
            foreach (var batch in Regex.Split(sql, @"^\s*GO\s*;?\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase))
            {
                if (string.IsNullOrWhiteSpace(batch))
                {
                    continue;
                }

                await using var command = connection.CreateCommand();
                command.CommandText = batch;
                command.CommandTimeout = 120;
                await command.ExecuteNonQueryAsync();
            }

            logger.LogInformation("Database schema and demo data are ready");
            return;
        }
        catch (Exception exception) when (attempt < 12)
        {
            logger.LogWarning(exception, "Database initialization attempt {Attempt} failed", attempt);
            await Task.Delay(TimeSpan.FromSeconds(10));
        }
    }
}

record Product(int Id, string Name, decimal Price, string Category);
