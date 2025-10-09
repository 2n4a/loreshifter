using Microsoft.AspNetCore.Mvc;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0")]
public class AuthController : ControllerBase
{
    [HttpGet("login")]
    public IActionResult Login([FromQuery] string provider = "google")
    {
        // TODO: Redirect to provider OAuth
        return Redirect($"https://provider/{provider}/auth");
    }

    [HttpGet("login/callback/{provider}")]
    public IActionResult LoginCallback(string provider)
    {
        // TODO: Handle OAuth callback
        throw new NotImplementedException();
    }

    [HttpGet("logout")]
    public IActionResult Logout()
    {
        // TODO: Clear session cookie
        throw new NotImplementedException();
    }
}
