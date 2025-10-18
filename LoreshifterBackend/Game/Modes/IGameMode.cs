using Loreshifter.Game.Sessions;

namespace Loreshifter.Game.Modes;

public abstract record GameModeState;

public record CreateSessionOptions(string? HostPlayerName, int? ExpectedPlayers, bool BossWinsScenario = false);

public enum GameOutcome
{
    Ongoing,
    BossDefeated,
    PlayersDefeated
}

public record GameTurnResolution(
    GameEvent Resolution,
    GameEvent? NextPrompt,
    IEnumerable<ActionSuggestion> NextSuggestions,
    GameOutcome Outcome);

public interface IGameMode
{
    string Id { get; }
    string Name { get; }

    GameSession CreateSession(CreateSessionOptions options);

    GameTurn CreateInitialTurn(GameSession session);

    GameTurnResolution ResolveTurn(GameSession session, GameTurn turn);
}