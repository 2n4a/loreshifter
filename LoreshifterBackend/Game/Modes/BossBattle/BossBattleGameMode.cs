using System.Collections.Generic;
using System.Linq;
using System.Text;
using Loreshifter.Game.Sessions;

namespace Loreshifter.Game.Modes.BossBattle;

public record BossBattleState(int BossHealth, int Rage, int Turn) : GameModeState;

public class BossBattleGameMode : IGameMode
{
    private static readonly string[] DefaultInventory = ["Magic Wand", "Steel Sword", "Field Bandage"];
    private readonly Random _random = new();

    public string Id => "boss-battle";
    public string Name => "Obsidian Titan Siege";

    public GameSession CreateSession(CreateSessionOptions options)
    {
        var session = new GameSession
        {
            Id = Guid.NewGuid(),
            Code = GenerateCode(),
            ModeId = Id,
            Title = "Siege of the Obsidian Titan",
            Prologue = BuildPrologue(),
            BossOverview = BuildBossOverview(),
            CreatedAt = DateTime.UtcNow,
            Phase = SessionPhase.AwaitingPlayerSetup,
            ExpectedPlayers = options.ExpectedPlayers,
            ModeState = new BossBattleState(BossHealth: 120, Rage: 10, Turn: 0)
        };

        if (!string.IsNullOrWhiteSpace(options.HostPlayerName))
        {
            var host = session.AddPlayer(options.HostPlayerName!);
            host.Setup.Inventory.AddRange(DefaultInventory);
        }

        return session;
    }

    public GameTurn CreateInitialTurn(GameSession session)
    {
        if (session.ModeState is not BossBattleState state)
        {
            throw new InvalidOperationException("Session state is not configured for the boss battle mode.");
        }

        var nextState = state with { Turn = 1 };
        session.ModeState = nextState;

        var turn = new GameTurn
        {
            TurnNumber = nextState.Turn,
            CreatedAt = DateTime.UtcNow,
            Prompt = new GameEvent
            {
                Title = "The Titan draws in cosmic fire",
                Description = "The obsidian titan raises both arms, drawing in swirling cosmic embers. The air vibrates with impending devastation. Each hero has only moments to respond before the inferno erupts.",
                CreatedAt = DateTime.UtcNow
            }
        };

        turn.SetSuggestions(BuildSuggestions());
        return turn;
    }

    public GameTurnResolution ResolveTurn(GameSession session, GameTurn turn)
    {
        if (session.ModeState is not BossBattleState state)
        {
            throw new InvalidOperationException("Session state is not configured for the boss battle mode.");
        }

        var impact = EstimateImpact(turn.Actions);
        var newHealth = Math.Max(0, state.BossHealth - impact);
        var newRage = Math.Min(100, state.Rage + 10 + turn.Actions.Count * 3);
        var nextTurnNumber = state.Turn + 1;

        var resolutionNarrative = BuildResolutionNarrative(turn.Actions, newHealth, newRage);
        var resolution = new GameEvent
        {
            Title = "Clash Resolution",
            Description = resolutionNarrative,
            CreatedAt = DateTime.UtcNow
        };

        var outcome = DetermineOutcome(session, newHealth);
        GameEvent? nextPrompt = null;

        if (outcome == GameOutcome.Ongoing)
        {
            nextPrompt = new GameEvent
            {
                Title = $"Boss counter-surge (Turn {nextTurnNumber})",
                Description = BuildNextPromptNarrative(newHealth, newRage),
                CreatedAt = DateTime.UtcNow
            };
        }

        session.ModeState = new BossBattleState(newHealth, newRage, nextTurnNumber);

        var suggestions = BuildSuggestions().ToList();
        return new GameTurnResolution(resolution, nextPrompt, suggestions, outcome);
    }

    private IEnumerable<ActionSuggestion> BuildSuggestions()
    {
        yield return new ActionSuggestion
        {
            Source = "guide",
            Content = "Coordinate a combined assault to interrupt the titan's channeling before the blast completes."
        };
        yield return new ActionSuggestion
        {
            Source = "guide",
            Content = "Use defensive or disruption abilities to shield the team from the impending firestorm."
        };
    }

    private static int EstimateImpact(IReadOnlyCollection<PlayerAction> actions)
    {
        if (actions.Count == 0)
        {
            return 0;
        }

        var baseImpact = actions.Count * 12;
        var creativityBonus = actions.Sum(action => Math.Min(18, action.Content.Length / 12));
        return baseImpact + creativityBonus;
    }

    private GameOutcome DetermineOutcome(GameSession session, int bossHealth)
    {
        if (bossHealth <= 0)
        {
            return GameOutcome.BossDefeated;
        }

        if (session.Players.All(player => !player.IsAlive))
        {
            return GameOutcome.PlayersDefeated;
        }

        return GameOutcome.Ongoing;
    }

    private string BuildResolutionNarrative(IEnumerable<PlayerAction> actions, int bossHealth, int rage)
    {
        if (!actions.Any())
        {
            return "The party hesitates, granting the titan an opportunity to reinforce its molten armor. The danger escalates.";
        }

        var builder = new StringBuilder();
        builder.AppendLine("The battlefield erupts as the heroes act in unison:");
        foreach (var action in actions)
        {
            builder.AppendLine($"- {action.PlayerName}: {action.Content}");
        }

        builder.AppendLine();
        builder.AppendLine(bossHealth <= 0
            ? "A resonant crack splits the titan's core as it collapses, scattering obsidian shards across the ruined arena. Victory!"
            : $"The titan staggers, molten cracks spiderwebbing its frame. Remaining vitality: {bossHealth}. Its fury now seethes at {rage}%.");

        return builder.ToString();
    }

    private string BuildNextPromptNarrative(int bossHealth, int rage)
    {
        var behaviour = rage switch
        {
            >= 80 => "The titan howls and prepares a catastrophic meteor storm, seeking to annihilate anyone standing.",
            >= 50 => "The titan gathers a tidal wave of molten glass, ready to sweep across the arena.",
            _ => "The titan braces, shards swirling defensively as it seeks an opening."
        };

        return $"The obsidian titan reels with {bossHealth} vitality remaining. {behaviour} Plan your next decisive actions.";
    }

    private string BuildPrologue()
    {
        return "For weeks the continent has shuddered under the wake of an obsidian colossus forged from dead stars. The heroes finally corner the titan at the heart of a shattered citadel, knowing this battle will decide the fate of the realm.";
    }

    private string BuildBossOverview()
    {
        return "Obsidian Titan — a colossal construct harnessing stellar embers. Strengths: devastating area attacks, resilient armor. Weaknesses: destabilizes when interrupted mid-channel, vulnerable joints at the shoulders and chest.";
    }

    private string GenerateCode()
    {
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        return string.Create(6, alphabet, (span, chars) =>
        {
            for (var i = 0; i < span.Length; i++)
            {
                span[i] = chars[_random.Next(chars.Length)];
            }
        });
    }
}