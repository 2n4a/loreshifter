using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Loreshifter.Data;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0/game")]
public class GamesController : ControllerBase
{
    private readonly AppDbContext _db;
    public GamesController(AppDbContext db) => _db = db;

    [HttpGet]
    public IActionResult GetGames(
        [FromQuery] int limit = 25,
        [FromQuery] int offset = 0,
        [FromQuery] string? sort = "createdAt",
        [FromQuery] string? order = "desc",
        [FromQuery] string? filter = null)
    {
        throw new NotImplementedException();
    }

    [HttpGet("{id:int}")]
    public IActionResult GetGameById(int id)
    {
        throw new NotImplementedException();
    }

    [HttpGet("code/{code}")]
    public IActionResult GetGameByCode(string code)
    {
        throw new NotImplementedException();
    }

    [Authorize]
    [HttpPost]
    public IActionResult CreateGame([FromBody] object newGame)
    {
        throw new NotImplementedException();
    }
}
