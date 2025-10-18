using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Loreshifter.Game.Sessions;

namespace Loreshifter.Game.Modes.BossBattle;

public record BossBattleState(int BossHealth, int Rage, int Turn) : GameModeState;

public class BossBattleGameMode : IGameMode
{
    private static readonly string[] DefaultInventory =
    [
        "weapon.staff",
        "weapon.sword",
        "consumable.bandage"
    ];
    private readonly Random _random = new();

    public string Id => "boss-battle";
    public string Name => "Obsidian Titan Siege";

    public GameSession CreateSession(CreateSessionOptions options)
    {
        var bossProfile = CloneBossProfile(BossBattleReferenceData.BossProfile);
        var worldLore = CloneWorldLore(BossBattleReferenceData.WorldLore);
        var characterRules = CloneCharacterRules(BossBattleReferenceData.CharacterRules);
        var session = new GameSession
        {
            Id = Guid.NewGuid(),
            Code = GenerateCode(),
            ModeId = Id,
            Title = "Siege of the Obsidian Titan",
            Prologue = BuildPrologue(worldLore, bossProfile),
            BossOverview = BuildBossOverview(bossProfile),
            CreatedAt = DateTime.UtcNow,
            Phase = SessionPhase.AwaitingPlayerSetup,
            ExpectedPlayers = options.ExpectedPlayers,
            ModeState = new BossBattleState(bossProfile.MaxHealth, bossProfile.StartingRage, 0),
            WorldLore = worldLore,
            CharacterCreation = characterRules,
            BossProfile = bossProfile
        };

        session.SetItemCatalog(BossBattleReferenceData.Items.Select(CloneItemDefinition));

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

        turn.SetSuggestions(BuildSuggestions(session));
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

        var resolutionNarrative = BuildResolutionNarrative(session.BossProfile, turn.Actions, newHealth, newRage);
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
                Description = BuildNextPromptNarrative(session.BossProfile, newHealth, newRage),
                CreatedAt = DateTime.UtcNow
            };
        }

        session.ModeState = new BossBattleState(newHealth, newRage, nextTurnNumber);

        var suggestions = BuildSuggestions(session).ToList();
        return new GameTurnResolution(resolution, nextPrompt, suggestions, outcome);
    }

    private IEnumerable<ActionSuggestion> BuildSuggestions(GameSession session)
    {
        var shield = session.ItemCatalog.FirstOrDefault(item => item.Id == "armor.shield");
        var bandage = session.ItemCatalog.FirstOrDefault(item => item.Id == "consumable.bandage");

        yield return new ActionSuggestion
        {
            Source = "guide",
            Content = "Coordinate a combined assault to interrupt the titan's channeling before the blast completes."
        };
        yield return new ActionSuggestion
        {
            Source = "guide",
            Content = shield is null
                ? "Use defensive or disruption abilities to shield the team from the impending firestorm."
                : $"Deploy {shield.Name} or similar defenses to deflect the titan's area blasts while allies strike."
        };

        if (bandage is not null)
        {
            yield return new ActionSuggestion
            {
                Source = "guide",
                Content = $"Reserve {bandage.Name} for emergency stabilization when a hero drops below half vitality."
            };
        }
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

    private string BuildResolutionNarrative(BossProfile profile, IEnumerable<PlayerAction> actions, int bossHealth, int rage)
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

        var phase = profile.RagePhases
            .OrderByDescending(p => p.RageThreshold)
            .FirstOrDefault(p => rage >= p.RageThreshold);

        if (phase is not null && bossHealth > 0)
        {
            builder.AppendLine();
            builder.AppendLine($"Rage phase response — {phase.Description} {phase.AttackProfile}");
        }

        return builder.ToString();
    }

    private string BuildNextPromptNarrative(BossProfile profile, int bossHealth, int rage)
    {
        var phase = profile.RagePhases
            .OrderByDescending(p => p.RageThreshold)
            .FirstOrDefault(p => rage >= p.RageThreshold);

        var behaviour = phase is null
            ? "The titan studies the battlefield, gauging your resolve."
            : phase.AttackProfile;

        return $"The obsidian titan reels with {bossHealth} vitality remaining. {behaviour} Plan your next decisive actions.";
    }

    private string BuildPrologue(WorldDescription world, BossProfile boss)
    {
        var builder = new StringBuilder();
        builder.AppendLine(world.Overview);
        builder.AppendLine();
        builder.AppendLine(world.Geography);
        builder.AppendLine();
        builder.AppendLine($"Последняя надежда городов-купол — герои, решившиеся остановить {boss.Title.ToLower()} по имени {boss.Name}.");
        return builder.ToString();
    }

    private string BuildBossOverview(BossProfile boss)
    {
        var builder = new StringBuilder();
        builder.AppendLine($"{boss.Name}, {boss.Title}.");
        builder.AppendLine(boss.Backstory);
        builder.AppendLine();
        builder.AppendLine($"Максимальные очки здоровья: {boss.MaxHealth}. Стартовая ярость: {boss.StartingRage}%.");
        builder.AppendLine($"Стиль боя: {boss.CombatStyle}");

        if (boss.SignatureEquipment.Any())
        {
            builder.AppendLine();
            builder.AppendLine("Ключевые артефакты:");
            foreach (var item in boss.SignatureEquipment)
            {
                builder.AppendLine($"- {item}");
            }
        }

        if (boss.RagePhases.Any())
        {
            builder.AppendLine();
            builder.AppendLine("Фазы ярости:");
            foreach (var phase in boss.RagePhases.OrderBy(p => p.RageThreshold))
            {
                builder.AppendLine($"- От {phase.RageThreshold}%: {phase.Description} {phase.AttackProfile}");
            }
        }

        return builder.ToString();
    }

    private static WorldDescription CloneWorldLore(WorldDescription source)
    {
        return new WorldDescription
        {
            Overview = source.Overview,
            Geography = source.Geography,
            MagicSystem = source.MagicSystem,
            Culture = source.Culture
        };
    }

    private static CharacterCreationRules CloneCharacterRules(CharacterCreationRules source)
    {
        return new CharacterCreationRules
        {
            TotalAssignablePoints = source.TotalAssignablePoints,
            Guidance = source.Guidance,
            Attributes = source.Attributes
                .Select(attribute => new CharacterAttributeDefinition
                {
                    Id = attribute.Id,
                    Name = attribute.Name,
                    Description = attribute.Description,
                    MinValue = attribute.MinValue,
                    MaxValue = attribute.MaxValue
                })
                .ToList()
        };
    }

    private static ItemDefinition CloneItemDefinition(ItemDefinition source)
    {
        return new ItemDefinition
        {
            Id = source.Id,
            Name = source.Name,
            Category = source.Category,
            Description = source.Description,
            ConsumedOnUse = source.ConsumedOnUse,
            Requirements = source.Requirements
                .Select(req => new ItemRequirement
                {
                    AttributeId = req.AttributeId,
                    RequiredPoints = req.RequiredPoints
                })
                .ToList(),
            Effects = source.Effects
                .Select(effect => new ItemEffect
                {
                    StatId = effect.StatId,
                    Description = effect.Description,
                    BaseValue = effect.BaseValue,
                    ScalingAttributeId = effect.ScalingAttributeId,
                    ScalingPerPoint = effect.ScalingPerPoint,
                    Unit = effect.Unit
                })
                .ToList()
        };
    }

    private static BossProfile CloneBossProfile(BossProfile source)
    {
        return new BossProfile
        {
            Name = source.Name,
            Title = source.Title,
            Backstory = source.Backstory,
            CombatStyle = source.CombatStyle,
            MaxHealth = source.MaxHealth,
            StartingRage = source.StartingRage,
            SignatureEquipment = source.SignatureEquipment.ToList(),
            RagePhases = source.RagePhases
                .Select(phase => new BossRagePhase
                {
                    RageThreshold = phase.RageThreshold,
                    Description = phase.Description,
                    AttackProfile = phase.AttackProfile
                })
                .ToList()
        };
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