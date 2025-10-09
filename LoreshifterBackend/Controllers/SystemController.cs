using Microsoft.AspNetCore.Mvc;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0")]
public class SystemController : ControllerBase
{
    [HttpGet("liveness")]
    public IActionResult Liveness() => Ok(new {});
}
