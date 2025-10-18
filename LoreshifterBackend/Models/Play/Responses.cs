using System.Linq;
using Loreshifter.Game.Modes;
using Loreshifter.Game.Modes.BossBattle;
using Loreshifter.Game.Sessions;

namespace Loreshifter.Models.Play;

public record GameSessionResponse(
    Guid Id,
    string Code,
    string ModeId,
    string Title,
    SessionPhase Phase,
    GameOutcome? Outcome,
    string Prologue,
    string BossOverview,
    int? ExpectedPlayers,
    BossBattleState? BossState,
    IReadOnlyList<GamePlayerResponse> Players,
    IReadOnlyList<GameTurnResponse> Turns,
    IReadOnlyList<PlayerChatMessageResponse> PlayerChat,
    IReadOnlyList<PlayerQuestionResponse> Questions
);

public record GamePlayerResponse(
    Guid Id,
    string Name,
    bool IsReady,
    bool IsAlive,
    PlayerSetupResponse Setup
);

public record PlayerSetupResponse(
    string? Class,
    string? SpecialAbility,
    IReadOnlyList<string> Inventory
);

public record GameTurnResponse(
    int TurnNumber,
    GameEventResponse Prompt,
    GameEventResponse? Resolution,
    IReadOnlyList<PlayerActionResponse> Actions,
    IReadOnlyList<ActionSuggestionResponse> Suggestions
);

public record GameEventResponse(
    string Title,
    string Description,
    DateTime CreatedAt
);

public record PlayerActionResponse(
    Guid PlayerId,
    string PlayerName,
    string Content,
    DateTime SubmittedAt
);

public record ActionSuggestionResponse(
    string Source,
    string Content
);

public record PlayerChatMessageResponse(
    Guid PlayerId,
    string PlayerName,
    string Content,
    DateTime CreatedAt
);

public record PlayerQuestionResponse(
    Guid PlayerId,
    string PlayerName,
    string Content,
    string? Response,
    DateTime CreatedAt
);

public static class PlaySessionMapper
{
    public static GameSessionResponse ToResponse(GameSession session)
    {
        var players = session.Players
            .Select(player => new GamePlayerResponse(
                player.Id,
                player.Name,
                player.IsReady,
                player.IsAlive,
                new PlayerSetupResponse(
                    player.Setup.Class,
                    player.Setup.SpecialAbility,
                    player.Setup.Inventory.AsReadOnly()))).ToList();

        var turns = session.Turns
            .Select(turn => new GameTurnResponse(
                turn.TurnNumber,
                new GameEventResponse(turn.Prompt.Title, turn.Prompt.Description, turn.Prompt.CreatedAt),
                turn.Resolution is null
                    ? null
                    : new GameEventResponse(turn.Resolution.Title, turn.Resolution.Description, turn.Resolution.CreatedAt),
                turn.Actions
                    .Select(action => new PlayerActionResponse(action.PlayerId, action.PlayerName, action.Content, action.SubmittedAt))
                    .ToList(),
                turn.Suggestions
                    .Select(suggestion => new ActionSuggestionResponse(suggestion.Source, suggestion.Content))
                    .ToList()))
            .ToList();

        var chat = session.PlayerChat
            .Select(message => new PlayerChatMessageResponse(message.PlayerId, message.PlayerName, message.Content, message.CreatedAt))
            .ToList();

        var questions = session.Questions
            .Select(question => new PlayerQuestionResponse(question.PlayerId, question.PlayerName, question.Content, question.Response, question.CreatedAt))
            .ToList();

        return new GameSessionResponse(
            session.Id,
            session.Code,
            session.ModeId,
            session.Title,
            session.Phase,
            session.Outcome,
            session.Prologue,
            session.BossOverview,
            session.ExpectedPlayers,
            session.GetState<BossBattleState>(),
            players,
            turns,
            chat,
            questions
        );
    }

    public static GamePlayerResponse ToPlayerResponse(GamePlayer player)
    {
        return new GamePlayerResponse(
            player.Id,
            player.Name,
            player.IsReady,
            player.IsAlive,
            new PlayerSetupResponse(
                player.Setup.Class,
                player.Setup.SpecialAbility,
                player.Setup.Inventory.AsReadOnly()));
    }
}