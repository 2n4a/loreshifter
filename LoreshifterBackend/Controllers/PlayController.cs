using Loreshifter.Game.Modes;
using Loreshifter.Game.Sessions;
using Loreshifter.Models.Play;
using Loreshifter.Services.Game;
using Microsoft.AspNetCore.Mvc;

namespace Loreshifter.Controllers;

[ApiController]
[Route("api/v0/play")]
public class PlayController : ControllerBase
{
    private readonly GameSessionManager _sessionManager;
    private readonly ILogger<PlayController> _logger;

    public PlayController(GameSessionManager sessionManager, ILogger<PlayController> logger)
    {
        _sessionManager = sessionManager;
        _logger = logger;
    }

    [HttpPost]
    public ActionResult<GameSessionResponse> CreateSession([FromBody] CreatePlaySessionRequest? request)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.Mode))
        {
            return BadRequest(new { message = "Mode is required." });
        }

        try
        {
            var options = new CreateSessionOptions(request.PlayerName, request.ExpectedPlayers);
            var session = _sessionManager.CreateSession(request.Mode, options);
            var response = PlaySessionMapper.ToResponse(session);
            return CreatedAtAction(nameof(GetById), new { sessionId = response.Id }, response);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Failed to create session");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("{sessionId:guid}")]
    public ActionResult<GameSessionResponse> GetById(Guid sessionId)
    {
        try
        {
            var session = _sessionManager.GetSession(sessionId);
            return Ok(PlaySessionMapper.ToResponse(session));
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session not found." });
        }
    }

    [HttpGet("code/{code}")]
    public ActionResult<GameSessionResponse> GetByCode(string code)
    {
        try
        {
            var session = _sessionManager.GetSession(code);
            return Ok(PlaySessionMapper.ToResponse(session));
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session not found." });
        }
    }

    [HttpPost("{sessionId:guid}/players")]
    public ActionResult<GamePlayerResponse> Join(Guid sessionId, [FromBody] JoinSessionRequest? request)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.PlayerName))
        {
            return BadRequest(new { message = "Player name is required." });
        }

        try
        {
            var player = _sessionManager.Join(sessionId, request.PlayerName);
            return Ok(PlaySessionMapper.ToPlayerResponse(player));
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session not found." });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPost("{sessionId:guid}/players/{playerId:guid}/setup")]
    public IActionResult ConfigurePlayer(Guid sessionId, Guid playerId, [FromBody] PlayerSetupRequest? request)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Setup payload is required." });
        }

        try
        {
            var setup = new PlayerSetup
            {
                Class = request.Class,
                SpecialAbility = request.SpecialAbility,
                Inventory = request.Inventory ?? new List<string>()
            };
            _sessionManager.UpdatePlayerSetup(sessionId, playerId, setup);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPost("{sessionId:guid}/players/{playerId:guid}/ready")]
    public IActionResult SetReady(Guid sessionId, Guid playerId, [FromBody] PlayerReadyRequest? request)
    {
        try
        {
            var ready = request?.Ready ?? true;
            _sessionManager.SetPlayerReady(sessionId, playerId, ready);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session or player not found." });
        }
    }

    [HttpPost("{sessionId:guid}/actions")]
    public IActionResult SubmitAction(Guid sessionId, [FromBody] SubmitActionRequest? request)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Action payload is required." });
        }

        if (request.PlayerId == Guid.Empty)
        {
            return BadRequest(new { message = "Player identifier is required." });
        }

        if (string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest(new { message = "Action content cannot be empty." });
        }

        try
        {
            _sessionManager.SubmitAction(sessionId, request.PlayerId, request.Content);
            return Accepted();
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session or player not found." });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPost("{sessionId:guid}/questions")]
    public IActionResult SubmitQuestion(Guid sessionId, [FromBody] SubmitQuestionRequest? request)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Question payload is required." });
        }

        if (request.PlayerId == Guid.Empty)
        {
            return BadRequest(new { message = "Player identifier is required." });
        }

        if (string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest(new { message = "Question cannot be empty." });
        }

        try
        {
            _sessionManager.SubmitQuestion(sessionId, request.PlayerId, request.Content);
            return Accepted();
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session or player not found." });
        }
    }

    [HttpPost("{sessionId:guid}/chat")]
    public IActionResult SubmitChat(Guid sessionId, [FromBody] SubmitChatMessageRequest? request)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Chat payload is required." });
        }

        if (request.PlayerId == Guid.Empty)
        {
            return BadRequest(new { message = "Player identifier is required." });
        }

        if (string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest(new { message = "Message cannot be empty." });
        }

        try
        {
            _sessionManager.SubmitPlayerChat(sessionId, request.PlayerId, request.Content);
            return Accepted();
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { message = "Session or player not found." });
        }
    }
}