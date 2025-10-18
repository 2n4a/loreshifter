using System;
using System.Collections.Concurrent;
using System.Linq;
using Loreshifter.Game.Modes;
using Loreshifter.Game.Sessions;
using Microsoft.Extensions.Logging;

namespace Loreshifter.Services.Game;

public class GameSessionManager
{
    private readonly ConcurrentDictionary<Guid, GameSession> _sessions = new();
    private readonly ConcurrentDictionary<string, Guid> _codeIndex = new(StringComparer.OrdinalIgnoreCase);
    private readonly IReadOnlyDictionary<string, IGameMode> _modes;
    private readonly ILogger<GameSessionManager> _logger;

    public GameSessionManager(IEnumerable<IGameMode> modes, ILogger<GameSessionManager> logger)
    {
        _modes = modes.ToDictionary(mode => mode.Id, StringComparer.OrdinalIgnoreCase);
        _logger = logger;
    }

    public GameSession CreateSession(string modeId, CreateSessionOptions options)
    {
        if (!_modes.TryGetValue(modeId, out var mode))
        {
            throw new ArgumentException($"Unknown game mode '{modeId}'.", nameof(modeId));
        }

        var session = mode.CreateSession(options);

        if (!string.Equals(session.ModeId, mode.Id, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"Game mode '{mode.Id}' returned a session with mismatched mode id '{session.ModeId}'.");
        }

        if (!_sessions.TryAdd(session.Id, session))
        {
            throw new InvalidOperationException("Failed to create a new game session.");
        }

        _codeIndex[session.Code] = session.Id;
        _logger.LogInformation("Created session {SessionId} for mode {ModeId}", session.Id, session.ModeId);
        return session;
    }

    public GameSession GetSession(Guid sessionId)
    {
        if (_sessions.TryGetValue(sessionId, out var session))
        {
            return session;
        }

        throw new KeyNotFoundException($"Session '{sessionId}' not found.");
    }

    public GameSession GetSession(string code)
    {
        if (_codeIndex.TryGetValue(code, out var sessionId))
        {
            return GetSession(sessionId);
        }

        throw new KeyNotFoundException($"Session with code '{code}' not found.");
    }

    public GamePlayer Join(Guid sessionId, string playerName)
    {
        var session = GetSession(sessionId);
        lock (session.SyncRoot)
        {
            if (session.Phase != SessionPhase.AwaitingPlayerSetup)
            {
                throw new InvalidOperationException("Cannot join a session that has already started.");
            }

            if (session.ExpectedPlayers is int expected && session.Players.Count >= expected)
            {
                throw new InvalidOperationException("The session is full.");
            }

            var player = session.AddPlayer(playerName);
            _logger.LogInformation("Player {Player} joined session {SessionId}", player.Id, session.Id);
            return player;
        }
    }

    public void UpdatePlayerSetup(Guid sessionId, Guid playerId, PlayerSetup setup)
    {
        var session = GetSession(sessionId);
        lock (session.SyncRoot)
        {
            var player = session.FindPlayer(playerId) ?? throw new KeyNotFoundException("Player not found in session.");
            player.Setup.Class = setup.Class;
            player.Setup.SpecialAbility = setup.SpecialAbility;
            player.Setup.Inventory = setup.Inventory?.ToList() ?? new List<string>();
        }
    }

    public void SetPlayerReady(Guid sessionId, Guid playerId, bool isReady)
    {
        var session = GetSession(sessionId);
        lock (session.SyncRoot)
        {
            var player = session.FindPlayer(playerId) ?? throw new KeyNotFoundException("Player not found in session.");
            player.IsReady = isReady;
            TryStartFirstTurn(session);
        }
    }

    public void SubmitAction(Guid sessionId, Guid playerId, string content)
    {
        var session = GetSession(sessionId);
        lock (session.SyncRoot)
        {
            if (session.Phase != SessionPhase.AwaitingActions)
            {
                throw new InvalidOperationException("The session is not ready for player actions.");
            }

            var player = session.FindPlayer(playerId) ?? throw new KeyNotFoundException("Player not found in session.");
            if (!player.IsAlive)
            {
                throw new InvalidOperationException("Eliminated players cannot submit actions.");
            }

            var turn = session.GetCurrentTurn() ?? throw new InvalidOperationException("No active turn is available.");
            var action = new PlayerAction
            {
                PlayerId = player.Id,
                PlayerName = player.Name,
                Content = content,
                SubmittedAt = DateTime.UtcNow
            };

            turn.UpsertAction(action);
            _logger.LogInformation("Player {PlayerId} submitted action for session {SessionId} turn {Turn}", playerId, sessionId, turn.TurnNumber);

            if (AllRequiredActionsSubmitted(session, turn))
            {
                ResolveTurn(session, turn);
            }
        }
    }

    public void SubmitQuestion(Guid sessionId, Guid playerId, string content)
    {
        var session = GetSession(sessionId);
        lock (session.SyncRoot)
        {
            var player = session.FindPlayer(playerId) ?? throw new KeyNotFoundException("Player not found in session.");
            session.AddQuestion(new PlayerQuestion
            {
                PlayerId = playerId,
                PlayerName = player.Name,
                Content = content,
                CreatedAt = DateTime.UtcNow,
                Response = null
            });
        }
    }

    public void SubmitPlayerChat(Guid sessionId, Guid playerId, string content)
    {
        var session = GetSession(sessionId);
        lock (session.SyncRoot)
        {
            var player = session.FindPlayer(playerId) ?? throw new KeyNotFoundException("Player not found in session.");
            session.AddChat(new PlayerChatMessage
            {
                PlayerId = playerId,
                PlayerName = player.Name,
                Content = content,
                CreatedAt = DateTime.UtcNow
            });
        }
    }

    private bool AllRequiredActionsSubmitted(GameSession session, GameTurn turn)
    {
        var alivePlayers = session.Players.Where(p => p.IsAlive).ToList();
        return alivePlayers.All(player => turn.HasActionFrom(player.Id));
    }

    private void ResolveTurn(GameSession session, GameTurn turn)
    {
        if (!_modes.TryGetValue(session.ModeId, out var mode))
        {
            throw new InvalidOperationException($"Session references unknown mode '{session.ModeId}'.");
        }

        session.Phase = SessionPhase.ResolvingTurn;
        var result = mode.ResolveTurn(session, turn);
        turn.Resolution = result.Resolution;

        if (result.Outcome != GameOutcome.Ongoing)
        {
            session.Phase = SessionPhase.Completed;
            session.Outcome = result.Outcome;
            return;
        }

        if (result.NextPrompt is not null)
        {
            var nextTurn = new GameTurn
            {
                TurnNumber = turn.TurnNumber + 1,
                CreatedAt = DateTime.UtcNow,
                Prompt = result.NextPrompt
            };

            var suggestions = result.NextSuggestions ?? Enumerable.Empty<ActionSuggestion>();
            nextTurn.SetSuggestions(suggestions);
            session.AddTurn(nextTurn);
        }

        session.Phase = SessionPhase.AwaitingActions;
    }

    private void TryStartFirstTurn(GameSession session)
    {
        if (session.Phase != SessionPhase.AwaitingPlayerSetup)
        {
            return;
        }

        if (!session.Players.Any())
        {
            return;
        }

        if (session.ExpectedPlayers is int expected && session.Players.Count < expected)
        {
            return;
        }

        if (session.Players.Any(player => !player.IsReady))
        {
            return;
        }

        if (!_modes.TryGetValue(session.ModeId, out var mode))
        {
            throw new InvalidOperationException($"Session references unknown mode '{session.ModeId}'.");
        }

        var initialTurn = mode.CreateInitialTurn(session);
        session.AddTurn(initialTurn);
        session.Phase = SessionPhase.AwaitingActions;
    }
}