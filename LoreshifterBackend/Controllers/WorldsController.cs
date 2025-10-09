using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Loreshifter.Data;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0/world")]
public class WorldsController : ControllerBase
{
    private readonly AppDbContext _db;
    public WorldsController(AppDbContext db) => _db = db;

    [HttpGet]
    public IActionResult GetWorlds(
        [FromQuery] int limit = 25,
        [FromQuery] int offset = 0,
        [FromQuery] string? sort = "lastUpdatedAt",
        [FromQuery] string? order = "desc",
        [FromQuery] string? search = null,
        [FromQuery] int? @public = null,
        [FromQuery] string? filter = null)
    {
        throw new NotImplementedException();
    }

    [HttpGet("{id}")]
    public IActionResult GetWorld(int id, [FromQuery] string? include = null)
    {
        throw new NotImplementedException();
    }

    [Authorize]
    [HttpPost]
    public IActionResult CreateWorld([FromBody] object newWorld)
    {
        throw new NotImplementedException();
    }

    [Authorize]
    [HttpPut("{id}")]
    public IActionResult UpdateWorld(int id, [FromBody] object update)
    {
        throw new NotImplementedException();
    }

    [Authorize]
    [HttpDelete("{id}")]
    public IActionResult DeleteWorld(int id)
    {
        throw new NotImplementedException();
    }

    [Authorize]
    [HttpPost("{id}/copy")]
    public IActionResult CopyWorld(int id)
    {
        throw new NotImplementedException();
    }

    [HttpGet("{id}/history")]
    public IActionResult GetWorldHistory(int id)
    {
        // TODO
        throw new NotImplementedException();
    }
}
