using System;
using System.Collections.Generic;
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
    WorldLoreResponse WorldLore,
    CharacterCreationRulesResponse CharacterCreation,
    BossProfileResponse BossProfile,
    IReadOnlyList<ItemDefinitionResponse> ItemCatalog,
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
    CharacterSheetResponse Character,
    IReadOnlyList<string> Inventory
);

public record CharacterSheetResponse(
    string? Name,
    string? Concept,
    string? Backstory,
    string? SpecialAbilityName,
    string? SpecialAbilityDescription,
    IReadOnlyDictionary<string, int> Attributes
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

public record WorldLoreResponse(
    string Overview,
    string Geography,
    string MagicSystem,
    string Culture
);

public record CharacterCreationRulesResponse(
    int TotalAssignablePoints,
    string Guidance,
    IReadOnlyList<CharacterAttributeDefinitionResponse> Attributes
);

public record CharacterAttributeDefinitionResponse(
    string Id,
    string Name,
    string Description,
    int MinValue,
    int MaxValue
);

public record ItemDefinitionResponse(
    string Id,
    string Name,
    ItemCategory Category,
    string Description,
    IReadOnlyList<ItemRequirementResponse> Requirements,
    IReadOnlyList<ItemEffectResponse> Effects,
    bool ConsumedOnUse
);

public record ItemRequirementResponse(
    string AttributeId,
    int RequiredPoints
);

public record ItemEffectResponse(
    string StatId,
    string Description,
    int BaseValue,
    string? ScalingAttributeId,
    double ScalingPerPoint,
    string Unit
);

public record BossProfileResponse(
    string Name,
    string Title,
    string Backstory,
    string CombatStyle,
    int MaxHealth,
    int StartingRage,
    IReadOnlyList<string> SignatureEquipment,
    IReadOnlyList<BossRagePhaseResponse> RagePhases
);

public record BossRagePhaseResponse(
    int RageThreshold,
    string Description,
    string AttackProfile
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
                    new CharacterSheetResponse(
                        player.Setup.Character.Name,
                        player.Setup.Character.Concept,
                        player.Setup.Character.Backstory,
                        player.Setup.Character.SpecialAbilityName,
                        player.Setup.Character.SpecialAbilityDescription,
                        new Dictionary<string, int>(player.Setup.Character.Attributes, StringComparer.OrdinalIgnoreCase)),
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

        var worldLore = new WorldLoreResponse(
            session.WorldLore.Overview,
            session.WorldLore.Geography,
            session.WorldLore.MagicSystem,
            session.WorldLore.Culture);

        var characterRules = new CharacterCreationRulesResponse(
            session.CharacterCreation.TotalAssignablePoints,
            session.CharacterCreation.Guidance,
            session.CharacterCreation.Attributes
                .Select(attr => new CharacterAttributeDefinitionResponse(
                    attr.Id,
                    attr.Name,
                    attr.Description,
                    attr.MinValue,
                    attr.MaxValue))
                .ToList());

        var bossProfile = session.BossProfile;
        var bossResponse = new BossProfileResponse(
            bossProfile.Name,
            bossProfile.Title,
            bossProfile.Backstory,
            bossProfile.CombatStyle,
            bossProfile.MaxHealth,
            bossProfile.StartingRage,
            bossProfile.SignatureEquipment.ToList(),
            bossProfile.RagePhases
                .Select(phase => new BossRagePhaseResponse(phase.RageThreshold, phase.Description, phase.AttackProfile))
                .ToList());

        var itemCatalog = session.ItemCatalog
            .Select(item => new ItemDefinitionResponse(
                item.Id,
                item.Name,
                item.Category,
                item.Description,
                item.Requirements
                    .Select(req => new ItemRequirementResponse(req.AttributeId, req.RequiredPoints))
                    .ToList(),
                item.Effects
                    .Select(effect => new ItemEffectResponse(effect.StatId, effect.Description, effect.BaseValue, effect.ScalingAttributeId, effect.ScalingPerPoint, effect.Unit))
                    .ToList(),
                item.ConsumedOnUse))
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
            worldLore,
            characterRules,
            bossResponse,
            itemCatalog,
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
                new CharacterSheetResponse(
                    player.Setup.Character.Name,
                    player.Setup.Character.Concept,
                    player.Setup.Character.Backstory,
                    player.Setup.Character.SpecialAbilityName,
                    player.Setup.Character.SpecialAbilityDescription,
                    new Dictionary<string, int>(player.Setup.Character.Attributes, StringComparer.OrdinalIgnoreCase)),
                player.Setup.Inventory.AsReadOnly()));
    }
}