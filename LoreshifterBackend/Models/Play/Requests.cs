namespace Loreshifter.Models.Play;

public record CreatePlaySessionRequest
{
    public string Mode { get; init; } = "boss-battle";
    public string? PlayerName { get; init; }
        = null;
    public int? ExpectedPlayers { get; init; }
        = null;
}

public record JoinSessionRequest
{
    public string PlayerName { get; init; } = string.Empty;
}

public record PlayerSetupRequest
{
    public string? Class { get; init; }
    public string? SpecialAbility { get; init; }
    public List<string>? Inventory { get; init; }
        = new();
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