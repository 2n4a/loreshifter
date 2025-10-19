using System.Collections.Generic;

namespace Loreshifter.Models.Play;

public record CreatePlaySessionRequest
{
    public string Mode { get; init; } = "boss-battle";
    public string? PlayerName { get; init; }
        = null;
    public int? ExpectedPlayers { get; init; }
        = null;
    public bool BossWinsScenario { get; init; }
        = false;
}

public record JoinSessionRequest
{
    public string PlayerName { get; init; } = string.Empty;
}

public record PlayerSetupRequest
{
    public Dictionary<string, int>? Attributes { get; init; }
    public List<string>? Inventory { get; init; } = new();
    public string? CharacterName { get; init; }
    public string? CharacterConcept { get; init; }
    public string? Backstory { get; init; }
    public string? SpecialAbilityName { get; init; }
    public string? SpecialAbilityDescription { get; init; }
}

public record PlayerReadyRequest
{
    public bool Ready { get; init; } = true;
}

public record SubmitActionRequest
{
    public Guid PlayerId { get; init; }
    public string Content { get; init; } = string.Empty;
}

public record SubmitQuestionRequest
{
    public Guid PlayerId { get; init; }
    public string Content { get; init; } = string.Empty;
}

public record SubmitChatMessageRequest
{
    public Guid PlayerId { get; init; }
    public string Content { get; init; } = string.Empty;
}