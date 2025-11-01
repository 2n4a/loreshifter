using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Loreshifter.Data;
using Loreshifter.Services;

namespace Loreshifter.Controllers;

public class GitHubTokenResponse
{
    public string access_token { get; set; } = string.Empty;
    public string token_type { get; set; } = string.Empty;
    public string scope { get; set; } = string.Empty;
}

public class GitHubUserResponse
{
    public string login { get; set; } = string.Empty;
    public long id { get; set; }
    public string avatar_url { get; set; } = string.Empty;
    public string name { get; set; } = string.Empty;
    public string email { get; set; } = string.Empty;
}

[ApiController]
[Route("api/v0")]
public class AuthController : ControllerBase
{
    private readonly ISecretManager _secretManager;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IDbContextFactory<AppDbContext> _dbContextFactory;
    private readonly IWebHostEnvironment _environment;
    private const string GitHubProvider = "github";
    

    public AuthController(
        ISecretManager secretManager, 
        IHttpClientFactory httpClientFactory,
        IDbContextFactory<AppDbContext> dbContextFactory,
        IWebHostEnvironment environment)
    {
        _secretManager = secretManager;
        _httpClientFactory = httpClientFactory;
        _dbContextFactory = dbContextFactory;
        _environment = environment;
    }

    [AllowAnonymous]
    [HttpGet("login")]
    public IActionResult Login([FromQuery] string provider)
    {
        if (provider != GitHubProvider)
        {
            return BadRequest("Unsupported provider");
        }

        var clientId = _secretManager.GetSecret("oauth2-github-client-id");
        if (string.IsNullOrEmpty(clientId))
        {
            return StatusCode(500, "GitHub OAuth client ID is not configured");
        }

        var redirectUri = Environment.GetEnvironmentVariable("OAUTH2_GITHUB_REDIRECT_URI") ?? "http://localhost:8000/api/v0/login/callback/github";
        var scope = "user:email";
        var url =
            $"https://github.com/login/oauth/authorize?client_id={Uri.EscapeDataString(clientId)}&redirect_uri={Uri.EscapeDataString(redirectUri)}&scope={Uri.EscapeDataString(scope)}";

        return Redirect(url);
    }

    [HttpGet("login/callback/{provider}")]
    public async Task<IActionResult> LoginCallback(string provider, [FromQuery] string code,
        [FromQuery] string? error = null)
    {
        if (provider != GitHubProvider)
        {
            return BadRequest("Unsupported provider");
        }

        if (!string.IsNullOrEmpty(error))
        {
            return BadRequest($"OAuth error: {error}");
        }

        if (string.IsNullOrEmpty(code))
        {
            return BadRequest("Authorization code is missing");
        }

        try
        {
            // Exchange the authorization code for an access token
            var tokenResponse = await ExchangeCodeForToken(code);

            // Get user info using the access token
            var userInfo = await GetGitHubUserInfo(tokenResponse.access_token);

            await using var context = await _dbContextFactory.CreateDbContextAsync();
            
            var user = await context.Users
                .FirstOrDefaultAsync(u => u.Email == userInfo.email || u.Name == userInfo.login);

            if (user == null)
            {
                user = new User
                {
                    Name = userInfo.login,
                    Email = userInfo.email,
                    CreatedAt = DateTimeOffset.UtcNow,
                    Deleted = false
                };

                context.Users.Add(user);
                await context.SaveChangesAsync();
            }

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new(ClaimTypes.Name, user.Name),
                new(ClaimTypes.Email, user.Email ?? string.Empty),
                new("GitHub:Login", userInfo.login),
                new("GitHub:AccessToken", tokenResponse.access_token)
            };

            var claimsIdentity = new ClaimsIdentity(
                claims, CookieAuthenticationDefaults.AuthenticationScheme);

            var authProperties = new AuthenticationProperties
            {
                AllowRefresh = true,
                IsPersistent = true,
                ExpiresUtc = DateTimeOffset.UtcNow.AddDays(30),
                IssuedUtc = DateTimeOffset.UtcNow
            };

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(claimsIdentity),
                authProperties);

            var frontendUrl = Environment.GetEnvironmentVariable("FRONTEND_URL") ?? "http://localhost:8080";
            return Redirect($"{frontendUrl}/auth-callback"); // потом поправим на норм адрес
        }
        catch (Exception ex)
        {
            return StatusCode(500, $"Authentication failed: {ex.Message}");
        }
    }

    private async Task<GitHubTokenResponse> ExchangeCodeForToken(string code)
    {
        string clientId;
        string clientSecret;
        
        try
        {
            clientId = _secretManager.GetSecret("oauth2-github-client-id");
            clientSecret = _secretManager.GetSecret("oauth2-github-client-secret");
        }
        catch (InvalidOperationException)
        {
            throw new InvalidOperationException("GitHub OAuth credentials are not properly configured");
        }

        var httpClient = _httpClientFactory.CreateClient();

        var requestBody = new
        {
            client_id = clientId,
            client_secret = clientSecret,
            code,
            redirect_uri = Environment.GetEnvironmentVariable("OAUTH2_GITHUB_REDIRECT_URI") ?? "http://localhost:8000/api/v0/login/callback/github"
        };

        var content = new StringContent(
            JsonSerializer.Serialize(requestBody),
            Encoding.UTF8,
            "application/json"
        );

        httpClient.DefaultRequestHeaders.Add("Accept", "application/json");

        var response = await httpClient.PostAsync("https://github.com/login/oauth/access_token", content);
        var responseContent = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException($"GitHub API request failed with status code {response.StatusCode}: {responseContent}");
        }

        var tokenResponse = JsonSerializer.Deserialize<GitHubTokenResponse>(responseContent);

        if (tokenResponse == null || string.IsNullOrEmpty(tokenResponse.access_token))
        {
            throw new InvalidOperationException($"Failed to retrieve access token from GitHub: {responseContent}");
        }

        return tokenResponse;
    }

    private async Task<GitHubUserResponse> GetGitHubUserInfo(string accessToken)
    {
        var httpClient = _httpClientFactory.CreateClient();
        httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        httpClient.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("Loreshifter", "1.0"));

        // Get user profile
        var userResponse = await httpClient.GetStringAsync("https://api.github.com/user");
        var user = JsonSerializer.Deserialize<GitHubUserResponse>(userResponse);

        if (user == null)
        {
            throw new InvalidOperationException($"Failed to retrieve user information from GitHub. Response: {userResponse}");
        }

        // Get user email if not available in the profile
        if (string.IsNullOrEmpty(user.email))
        {
            var emailsResponse = await httpClient.GetStringAsync("https://api.github.com/user/emails");
            var emails = JsonSerializer.Deserialize<List<GitHubUserEmail>>(emailsResponse);
            var primaryEmail = emails?.FirstOrDefault(e => e.primary)?.email;
            if (!string.IsNullOrEmpty(primaryEmail))
            {
                user.email = primaryEmail;
            }
        }

        return user;
    }

    [Authorize]
    [HttpGet("logout")]
    public async Task<IActionResult> Logout()
    {
        // Clear the authentication cookie
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

        // Clear the session
        HttpContext.Session.Clear();

        // Clear any other cookies if needed
        foreach (var cookie in Request.Cookies.Keys)
        {
            Response.Cookies.Delete(cookie);
        }

        return Ok(new { message = "Successfully logged out" });
    }

    [ApiExplorerSettings(IgnoreApi = true)]
    [AllowAnonymous]
    [HttpGet("test-login")]
    public async Task<IActionResult> TestLogin([FromQuery] string username, [FromQuery] string? email = null)
    {
        // Only allow in development
        if (!_environment.IsDevelopment())
        {
            return NotFound();
        }

        if (string.IsNullOrWhiteSpace(username))
        {
            return BadRequest("Username is required");
        }

        await using var context = await _dbContextFactory.CreateDbContextAsync();
        
        // Check if user exists
        var user = await context.Users
            .FirstOrDefaultAsync(u => u.Name == username);

        // Create test user if doesn't exist
        if (user == null)
        {
            user = new User
            {
                Name = username,
                Email = !string.IsNullOrWhiteSpace(email) ? email : $"{username}@test.local",
                CreatedAt = DateTimeOffset.UtcNow,
                Deleted = false
            };

            context.Users.Add(user);
            await context.SaveChangesAsync();
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Name),
            new(ClaimTypes.Email, user.Email ?? string.Empty),
            new("IsTestUser", "true")
        };

        var claimsIdentity = new ClaimsIdentity(
            claims, CookieAuthenticationDefaults.AuthenticationScheme);

        var authProperties = new AuthenticationProperties
        {
            AllowRefresh = true,
            IsPersistent = true,
            ExpiresUtc = DateTimeOffset.UtcNow.AddDays(1)
        };

        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(claimsIdentity),
            authProperties);

        return Ok(new { 
            user.Id, 
            user.Name, 
            user.Email,
            IsTestUser = true
        });
    }
}

public class GitHubUserEmail
{
    public string email { get; set; } = string.Empty;
    public bool primary { get; set; }
    public bool verified { get; set; }
    public string visibility { get; set; } = string.Empty;
}