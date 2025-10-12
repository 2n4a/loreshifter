using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Loreshifter.Data;
using Loreshifter.Models;
using System.Security.Claims;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0/user")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;
    public UsersController(AppDbContext db) => _db = db;

    [HttpGet("{id}")]
    public async Task<IActionResult> GetUser(string id)
    {
        try
        {
            // Handle "me" or "0" case
            if (id == "me" || id == "0")
            {
                if (!User.Identity?.IsAuthenticated ?? true)
                {
                    return Unauthorized(new { code = "Unauthorized", message = "Authentication required" });
                }

                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId) || !int.TryParse(userId, out var currentUserId))
                {
                    return Unauthorized(new { code = "Unauthorized", message = "Invalid user identity" });
                }

                return await GetUserById(currentUserId, fullPermission: true);
            }

            // Handle numeric ID case
            if (int.TryParse(id, out var requestedId))
            {
                // Check if user is requesting their own data
                var isSelf = User.Identity?.IsAuthenticated == true &&
                             int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentId) &&
                             currentId == requestedId;

                return await GetUserById(requestedId, isSelf);
            }

            return BadRequest(new { code = "InvalidId", message = "Invalid user ID format" });
        }
        catch (Exception ex)
        {
            return StatusCode(500,
                new { code = "InternalError", message = "An error occurred while processing your request" });
        }
    }

    private async Task<IActionResult> GetUserById(int id, bool fullPermission = false)
    {
        var user = await _db.Users
            .AsNoTracking()
            .Select(u => new
            {
                u.Id,
                u.Name,
                u.Deleted,
                Email = fullPermission ? u.Email : null,
            })
            .FirstOrDefaultAsync(u => u.Id == id && !u.Deleted);

        if (user == null)
        {
            return NotFound(new { code = "UserNotFound", message = "User not found" });
        }

        return Ok(user);
    }

    [Authorize]
    [HttpPut("{id?}")]
    public async Task<IActionResult> UpdateUser(string? id, [FromBody] UpdateUserRequest updateRequest)
    {
        try
        {
            // Get current user ID from claims
            var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(currentUserId) || !int.TryParse(currentUserId, out var userId))
            {
                return Unauthorized(new { code = "Unauthorized", message = "Invalid user identity" });
            }

            if (!string.IsNullOrEmpty(id) && id != "me" && id != "0")
            {
                if (!int.TryParse(id, out var requestedId) || requestedId != userId)
                {
                    return Forbid();
                }
            }

            var user = await _db.Users
                .FirstOrDefaultAsync(u => u.Id == userId && !u.Deleted);

            if (user == null)
            {
                return NotFound(new { code = "UserNotFound", message = "User not found" });
            }

            if (updateRequest.Name != null)
            {
                user.Name = updateRequest.Name;
            }

            // TODO: Email updates are not allowed yet (will require email confirmation)
            if (updateRequest.Email != null && updateRequest.Email != user.Email)
            {
                return BadRequest(new
                    { code = "EmailUpdateNotAllowed", message = "Email updates are not currently allowed" });
            }

            await _db.SaveChangesAsync();

            return Ok(new
            {
                user.Id,
                user.Name,
                user.Email
            });
        }
        catch (DbUpdateConcurrencyException)
        {
            return StatusCode(StatusCodes.Status409Conflict,
                new
                {
                    code = "ConcurrencyError",
                    message = "The record you attempted to update was modified by another user"
                });
        }
        catch (Exception ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { code = "UpdateFailed", message = "An error occurred while updating the user" });
        }
    }

    [HttpGet("{id}/history")]
    public IActionResult GetUserHistory(int id)
    {
        // TODO
        throw new NotImplementedException();
    }
}