using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Loreshifter.Data;
using Loreshifter.Models;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0/user")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;
    public UsersController(AppDbContext db) => _db = db;

    [HttpGet("{id}")]
    public IActionResult GetUser(string id)
    {
        // TODO: Implement lookup by id or "me"
        throw new NotImplementedException();
    }

    [Authorize]
    [HttpPut("{id?}")]
    public IActionResult UpdateUser(string? id, [FromBody] object update)
    {
        // TODO: Partial<User> update
        throw new NotImplementedException();
    }

    [HttpGet("{id}/history")]
    public IActionResult GetUserHistory(int id)
    {
        // TODO
        throw new NotImplementedException();
    }
}
