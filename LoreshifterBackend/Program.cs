using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.EntityFrameworkCore;
using Loreshifter.Data;
using Loreshifter.Services;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.KeyManagement;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models;
using System.Reflection;
using Loreshifter.Swagger;

// Load environment variables from .env file
var envPath = Path.Combine(Directory.GetCurrentDirectory(), "..", ".env");
if (File.Exists(envPath))
{
    DotNetEnv.Env.Load(envPath);
}

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddScoped<ISecretManager, SecretManager>();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v0", new OpenApiInfo
    {
        Version = "v0",
        Title = "Loreshifter API",
    });

    // Include XML comments for better documentation
    var xmlFilename = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    options.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, xmlFilename));
    
    // Add JWT Authentication
    options.AddSecurityDefinition("oauth2", new OpenApiSecurityScheme
    {
        Description = "Standard Authorization header using the Bearer scheme. Example: \"bearer {token}\"",
        In = ParameterLocation.Header,
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey,
        Scheme = "bearer"
    });

    options.OperationFilter<SecurityRequirementsOperationFilter>();
});

builder.Services.AddControllers();

var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "localhost";
var dbPort = Environment.GetEnvironmentVariable("DB_PORT") ?? "5432";
var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "devdb";
var dbUser = Environment.GetEnvironmentVariable("DB_USER") ?? "devuser";

var connectionString = $"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={{0}}";

builder.Services.AddDbContextFactory<AppDbContext>((serviceProvider, options) =>
{
    var secretManager = serviceProvider.GetRequiredService<ISecretManager>();
    var dbPassword = secretManager.GetSecret("db-password", "devpass");
    options.UseNpgsql(string.Format(connectionString, dbPassword));
});

builder.Services.AddSingleton<PostgresXmlRepository>();

builder.Services.AddDataProtection()
    .SetApplicationName("Loreshifter")
    .Services.AddSingleton<IConfigureOptions<KeyManagementOptions>>(sp =>
        new ConfigureOptions<KeyManagementOptions>(options =>
        {
            options.XmlRepository = sp.GetRequiredService<PostgresXmlRepository>();
        }));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddHttpClient();
builder.Services.AddDistributedMemoryCache();

builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.Name = "session";
    options.Cookie.IsEssential = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.Cookie.SameSite = SameSiteMode.Lax;
});

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.LoginPath = "/api/v0/login";
        options.LogoutPath = "/api/v0/logout";
        options.ExpireTimeSpan = TimeSpan.FromDays(30);
        options.SlidingExpiration = true;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v0/swagger.json", "v0");
    options.RoutePrefix = "swagger";
});

app.UseRouting();
app.UseSession();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
