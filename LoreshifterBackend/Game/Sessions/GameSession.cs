using Loreshifter.Game.Modes;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;

namespace Loreshifter.Game.Sessions;

public enum SessionPhase
{
    AwaitingPlayerSetup,
    AwaitingActions,
    ResolvingTurn,
    Completed
}

public class GameSession
{
    private readonly List<GamePlayer> _players = new();
    private readonly List<GameTurn> _turns = new();
    private readonly List<PlayerChatMessage> _playerChat = new();
    private readonly List<PlayerQuestion> _questions = new();
    private readonly List<ItemDefinition> _itemCatalog = new();

    public Guid Id { get; init; } = Guid.NewGuid();
    public string Code { get; init; } = string.Empty;
    public string ModeId { get; init; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
    public SessionPhase Phase { get; set; } = SessionPhase.AwaitingPlayerSetup;
    public int? ExpectedPlayers { get; set; }
    public GameOutcome? Outcome { get; set; }
    public string Prologue { get; set; } = string.Empty;
    public WorldDescription WorldLore { get; set; } = new();
    public CharacterCreationRules CharacterCreation { get; set; } = new();
    public BossProfile BossProfile { get; set; } = new();
    public string BossOverview { get; set; } = string.Empty;
    public GameModeState ModeState { get; set; } = default!;

    public IReadOnlyCollection<GamePlayer> Players => new ReadOnlyCollection<GamePlayer>(_players);
    public IReadOnlyCollection<GameTurn> Turns => new ReadOnlyCollection<GameTurn>(_turns);
    public IReadOnlyCollection<PlayerChatMessage> PlayerChat => new ReadOnlyCollection<PlayerChatMessage>(_playerChat);
    public IReadOnlyCollection<PlayerQuestion> Questions => new ReadOnlyCollection<PlayerQuestion>(_questions);
    public IReadOnlyCollection<ItemDefinition> ItemCatalog => new ReadOnlyCollection<ItemDefinition>(_itemCatalog);

    public object SyncRoot { get; } = new();

    public void SetItemCatalog(IEnumerable<ItemDefinition> items)
    {
        _itemCatalog.Clear();
        _itemCatalog.AddRange(items);
    }

    public GamePlayer AddPlayer(string name)
    {
        var player = new GamePlayer
        {
            Id = Guid.NewGuid(),
            Name = name
        };
        _players.Add(player);
        return player;
    }

    public GamePlayer? FindPlayer(Guid playerId) => _players.FirstOrDefault(p => p.Id == playerId);

    public void RemovePlayer(Guid playerId)
    {
        _players.RemoveAll(p => p.Id == playerId);
    }

    public void AddTurn(GameTurn turn) => _turns.Add(turn);

    public GameTurn? GetCurrentTurn() => _turns.LastOrDefault(t => !t.IsResolved);

    public GameTurn? GetLastTurn() => _turns.LastOrDefault();

    public void AddChat(PlayerChatMessage message) => _playerChat.Add(message);

    public void AddQuestion(PlayerQuestion question) => _questions.Add(question);

    public TState? GetState<TState>() where TState : GameModeState => ModeState as TState;
}

public class GameTurn
{
    private readonly List<PlayerAction> _actions = new();
    private readonly List<ActionSuggestion> _suggestions = new();

    public int TurnNumber { get; init; }
    public GameEvent Prompt { get; init; } = new();
    public GameEvent? Resolution { get; set; }
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;

    public IReadOnlyCollection<PlayerAction> Actions => _actions.AsReadOnly();
    public IReadOnlyCollection<ActionSuggestion> Suggestions => _suggestions.AsReadOnly();

    public bool IsResolved => Resolution is not null;

    public void UpsertAction(PlayerAction action)
    {
        var index = _actions.FindIndex(a => a.PlayerId == action.PlayerId);
        if (index >= 0)
        {
            _actions[index] = action;
        }
        else
        {
            _actions.Add(action);
        }
    }

    public bool HasActionFrom(Guid playerId) => _actions.Any(a => a.PlayerId == playerId);

    public void SetSuggestions(IEnumerable<ActionSuggestion> suggestions)
    {
        _suggestions.Clear();
        _suggestions.AddRange(suggestions);
    }
}

public class GameEvent
{
    public string Title { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
}

public class PlayerAction
{
    public Guid PlayerId { get; init; }
    public string PlayerName { get; init; } = string.Empty;
    public string Content { get; init; } = string.Empty;
    public DateTime SubmittedAt { get; init; } = DateTime.UtcNow;
}

public class ActionSuggestion
{
    public string Source { get; init; } = "system";
    public string Content { get; init; } = string.Empty;
}

public class PlayerChatMessage
{
    public Guid PlayerId { get; init; }
    public string PlayerName { get; init; } = string.Empty;
    public string Content { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
}

public class PlayerQuestion
{
    public Guid PlayerId { get; init; }
    public string PlayerName { get; init; } = string.Empty;
    public string Content { get; init; } = string.Empty;
    public string? Response { get; set; }
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
}

public class GamePlayer
{
    public Guid Id { get; init; }
    public string Name { get; set; } = string.Empty;
    public PlayerSetup Setup { get; set; } = new();
    public bool IsReady { get; set; }
    public bool IsAlive { get; set; } = true;
}

public class PlayerSetup
{
    public CharacterSheet Character { get; set; } = new();
    public List<string> Inventory { get; set; } = new();
}

public class CharacterSheet
{
    public string? Name { get; set; }
    public string? Concept { get; set; }
    public string? Backstory { get; set; }
    public string? SpecialAbilityName { get; set; }
    public string? SpecialAbilityDescription { get; set; }
    public Dictionary<string, int> Attributes { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

public class WorldDescription
{
    public string Overview { get; set; } = string.Empty;
    public string Geography { get; set; } = string.Empty;
    public string MagicSystem { get; set; } = string.Empty;
    public string Culture { get; set; } = string.Empty;
}

public class CharacterCreationRules
{
    public IReadOnlyList<CharacterAttributeDefinition> Attributes { get; init; } = Array.Empty<CharacterAttributeDefinition>();
    public int TotalAssignablePoints { get; init; }
    public string Guidance { get; init; } = string.Empty;
}

public class CharacterAttributeDefinition
{
    public string Id { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public int MinValue { get; init; }
    public int MaxValue { get; init; } = 7;
}

public enum ItemCategory
{
    Attack,
    Defense,
    Healing
}

public class ItemRequirement
{
    public string AttributeId { get; init; } = string.Empty;
    public int RequiredPoints { get; init; }
}

public class ItemEffect
{
    public string StatId { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public int BaseValue { get; init; }
    public string? ScalingAttributeId { get; init; }
    public double ScalingPerPoint { get; init; }
    public string Unit { get; init; } = string.Empty;
}

public class ItemDefinition
{
    public string Id { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public ItemCategory Category { get; init; }
    public string Description { get; init; } = string.Empty;
    public IReadOnlyList<ItemRequirement> Requirements { get; init; } = Array.Empty<ItemRequirement>();
    public IReadOnlyList<ItemEffect> Effects { get; init; } = Array.Empty<ItemEffect>();
    public bool ConsumedOnUse { get; init; }
}

public class BossProfile
{
    public string Name { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public string Backstory { get; init; } = string.Empty;
    public string CombatStyle { get; init; } = string.Empty;
    public int MaxHealth { get; init; }
    public int StartingRage { get; init; }
    public IReadOnlyList<string> SignatureEquipment { get; init; } = Array.Empty<string>();
    public IReadOnlyList<BossRagePhase> RagePhases { get; init; } = Array.Empty<BossRagePhase>();
}

public class BossRagePhase
{
    public int RageThreshold { get; init; }
    public string Description { get; init; } = string.Empty;
    public string AttackProfile { get; init; } = string.Empty;
}