using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace Loreshifter.Data
{
    public enum GameStatus { waiting, playing, finished, archived }
    public enum ChatType { room, character_creation, game, advice }
    public enum ChatInterfaceType { @readonly, foreign, full, timed, foreignTimed }
    public enum MessageKind { player, system, characterCreation, generalInfo, publicInfo, privateInfo }

    public class DataProtectionKey
    {
        public int Id { get; set; }
        public string FriendlyName { get; set; } = default!;
        public string Xml { get; set; } = default!;
        public DateTime CreationTime { get; set; } = DateTime.UtcNow;
    }

    public class User
    {
        public int Id { get; set; }
        public string Name { get; set; } = null!;
        public string? Email { get; set; }
        public int? AuthId { get; set; }
        public DateTimeOffset CreatedAt { get; set; }
        public bool Deleted { get; set; }

        public ICollection<World> Worlds { get; set; } = new List<World>();
        public ICollection<Game> HostedGames { get; set; } = new List<Game>();
        public ICollection<GamePlayer> GamePlayers { get; set; } = new List<GamePlayer>();
        public ICollection<Chat> OwnedChats { get; set; } = new List<Chat>();
        public ICollection<Message> SentMessages { get; set; } = new List<Message>();
    }

    public class World
    {
        public int Id { get; set; }
        public string Name { get; set; } = null!;
        public bool Public { get; set; }
        public int OwnerId { get; set; }
        public User Owner { get; set; } = null!;
        public string? Description { get; set; }
        public JsonDocument? Data { get; set; }
        public DateTimeOffset CreatedAt { get; set; }
        public DateTimeOffset LastUpdatedAt { get; set; }
        public bool Deleted { get; set; }

        public ICollection<Game> Games { get; set; } = new List<Game>();
    }

    public class Game
    {
        public int Id { get; set; }
        public string Code { get; set; } = null!;
        public string Name { get; set; } = null!;
        public bool Public { get; set; }
        public int WorldId { get; set; }
        public World World { get; set; } = null!;
        public int HostId { get; set; }
        public User Host { get; set; } = null!;
        public int MaxPlayers { get; set; }
        public GameStatus Status { get; set; }
        public DateTimeOffset CreatedAt { get; set; }

        public ICollection<GamePlayer> Players { get; set; } = new List<GamePlayer>();
        public ICollection<Chat> Chats { get; set; } = new List<Chat>();
        public ICollection<GameHistory> Histories { get; set; } = new List<GameHistory>();
    }

    public class GamePlayer
    {
        public int GameId { get; set; }
        public Game Game { get; set; } = null!;
        public int UserId { get; set; }
        public User User { get; set; } = null!;
        public bool IsReady { get; set; }
        public bool IsHost { get; set; }
        public bool IsSpectator { get; set; }
        public bool IsJoined { get; set; }
        public DateTimeOffset JoinedAt { get; set; }
    }

    public class Chat
    {
        public int Id { get; set; }
        public int? GameId { get; set; }
        public Game? Game { get; set; }
        public ChatType ChatType { get; set; }
        public int? OwnerId { get; set; }
        public User? Owner { get; set; }
        public ChatInterfaceType InterfaceType { get; set; }
        public DateTimeOffset? Deadline { get; set; }

        public ICollection<Message> Messages { get; set; } = new List<Message>();
        public ICollection<ChatSuggestion> Suggestions { get; set; } = new List<ChatSuggestion>();
    }

    public class Message
    {
        public int Id { get; set; }
        public int ChatId { get; set; }
        public Chat Chat { get; set; } = null!;
        public int? SenderId { get; set; }
        public User? Sender { get; set; }
        public MessageKind Kind { get; set; }
        public string Text { get; set; } = null!;
        public string? Special { get; set; }
        public JsonDocument? Metadata { get; set; }
        public DateTimeOffset SentAt { get; set; }
    }

    public class ChatSuggestion
    {
        public int Id { get; set; }
        public int ChatId { get; set; }
        public Chat Chat { get; set; } = null!;
        public string Suggestion { get; set; } = null!;
    }

    public class GameHistory
    {
        public int Id { get; set; }
        public int GameId { get; set; }
        public Game Game { get; set; } = null!;
        public JsonDocument Snapshot { get; set; } = null!;
        public DateTimeOffset CreatedAt { get; set; }
    }

    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<DataProtectionKey> DataProtectionKeys => Set<DataProtectionKey>();
        public DbSet<User> Users => Set<User>();
        public DbSet<World> Worlds => Set<World>();
        public DbSet<Game> Games => Set<Game>();
        public DbSet<GamePlayer> GamePlayers => Set<GamePlayer>();
        public DbSet<Chat> Chats => Set<Chat>();
        public DbSet<Message> Messages => Set<Message>();
        public DbSet<ChatSuggestion> ChatSuggestions => Set<ChatSuggestion>();
        public DbSet<GameHistory> GameHistory => Set<GameHistory>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.HasPostgresEnum<GameStatus>("game_status");
            modelBuilder.HasPostgresEnum<ChatType>("chat_type");
            modelBuilder.HasPostgresEnum<ChatInterfaceType>("chat_interface_type");
            modelBuilder.HasPostgresEnum<MessageKind>("message_kind");

            modelBuilder.Entity<DataProtectionKey>(b =>
            {
                b.ToTable("data_protection_keys");
                b.HasKey(e => e.Id).HasName("data_protection_keys_pkey");
                b.Property(e => e.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(e => e.FriendlyName).HasColumnName("friendly_name");
                b.Property(e => e.Xml).HasColumnName("xml").IsRequired();
                b.Property(e => e.CreationTime)
                    .HasColumnName("creation_time")
                    .HasDefaultValueSql("now()");
            });

            modelBuilder.Entity<User>(b =>
            {
                b.ToTable("users");
                b.HasKey(x => x.Id).HasName("users_pkey");
                b.Property(x => x.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(x => x.Name).HasColumnName("name").IsRequired();
                b.Property(x => x.Email).HasColumnName("email");
                b.HasIndex(x => x.Email).IsUnique().HasDatabaseName("users_email_key");
                b.Property(x => x.AuthId).HasColumnName("auth_id");
                b.HasIndex(x => x.AuthId).IsUnique().HasDatabaseName("users_auth_id_key");
                b.Property(x => x.CreatedAt).HasColumnName("created_at").IsRequired();
                b.Property(x => x.Deleted).HasColumnName("deleted").IsRequired();
            });

            modelBuilder.Entity<World>(b =>
            {
                b.ToTable("worlds");
                b.HasKey(x => x.Id).HasName("worlds_pkey");
                b.Property(x => x.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(x => x.Name).HasColumnName("name").IsRequired();
                b.Property(x => x.Public).HasColumnName("public").IsRequired();
                b.Property(x => x.OwnerId).HasColumnName("owner_id").IsRequired();
                b.Property(x => x.Description).HasColumnName("description");
                b.Property(x => x.Data).HasColumnName("data").HasColumnType("jsonb");
                b.Property(x => x.CreatedAt).HasColumnName("created_at").IsRequired();
                b.Property(x => x.LastUpdatedAt).HasColumnName("last_updated_at").IsRequired();

                b.HasOne(w => w.Owner)
                 .WithMany(u => u.Worlds)
                 .HasForeignKey(w => w.OwnerId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasIndex(w => w.OwnerId).HasDatabaseName("idx_worlds_owner");
            });

            modelBuilder.Entity<Game>(b =>
            {
                b.ToTable("games");
                b.HasKey(x => x.Id).HasName("games_pkey");
                b.Property(x => x.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(x => x.Code).HasColumnName("code").IsRequired();
                b.HasIndex(x => x.Code).IsUnique().HasDatabaseName("games_code_key");
                b.Property(x => x.Name).HasColumnName("name").IsRequired();
                b.Property(x => x.Public).HasColumnName("public").IsRequired();
                b.Property(x => x.WorldId).HasColumnName("world_id").IsRequired();
                b.Property(x => x.HostId).HasColumnName("host_id").IsRequired();
                b.Property(x => x.MaxPlayers).HasColumnName("max_players").IsRequired();
                b.Property(x => x.Status).HasColumnName("status").HasColumnType("game_status").IsRequired();
                b.Property(x => x.CreatedAt).HasColumnName("created_at").IsRequired();

                b.HasOne(g => g.World)
                 .WithMany(w => w.Games)
                 .HasForeignKey(g => g.WorldId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(g => g.Host)
                 .WithMany(u => u.HostedGames)
                 .HasForeignKey(g => g.HostId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasIndex(g => g.WorldId).HasDatabaseName("idx_games_world");
                b.HasIndex(g => g.HostId).HasDatabaseName("idx_games_host");
            });

            modelBuilder.Entity<GamePlayer>(b =>
            {
                b.ToTable("game_players");
                b.HasKey(gp => new { gp.GameId, gp.UserId }).HasName("game_players_pkey");

                b.Property(gp => gp.GameId).HasColumnName("game_id");
                b.Property(gp => gp.UserId).HasColumnName("user_id");
                b.Property(gp => gp.IsReady).HasColumnName("is_ready").IsRequired();
                b.Property(gp => gp.IsHost).HasColumnName("is_host").IsRequired();
                b.Property(gp => gp.IsSpectator).HasColumnName("is_spectator").IsRequired();
                b.Property(gp => gp.IsJoined).HasColumnName("is_joined").IsRequired();
                b.Property(gp => gp.JoinedAt).HasColumnName("joined_at").IsRequired();

                b.HasOne(gp => gp.Game)
                 .WithMany(g => g.Players)
                 .HasForeignKey(gp => gp.GameId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(gp => gp.User)
                 .WithMany(u => u.GamePlayers)
                 .HasForeignKey(gp => gp.UserId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasIndex(gp => gp.UserId).HasDatabaseName("idx_game_players_user");
            });

            modelBuilder.Entity<Chat>(b =>
            {
                b.ToTable("chats");
                b.HasKey(c => c.Id).HasName("chats_pkey");
                b.Property(c => c.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(c => c.GameId).HasColumnName("game_id");
                b.Property(c => c.ChatType).HasColumnName("chat_type").HasColumnType("chat_type").IsRequired();
                b.Property(c => c.OwnerId).HasColumnName("owner_id");
                b.Property(c => c.InterfaceType).HasColumnName("interface_type").HasColumnType("chat_interface_type").IsRequired();
                b.Property(c => c.Deadline).HasColumnName("deadline");

                b.HasOne(c => c.Game)
                 .WithMany(g => g.Chats)
                 .HasForeignKey(c => c.GameId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(c => c.Owner)
                 .WithMany(u => u.OwnedChats)
                 .HasForeignKey(c => c.OwnerId)
                 .OnDelete(DeleteBehavior.SetNull);

                b.HasIndex(c => c.GameId).HasDatabaseName("idx_chats_game");
            });

            modelBuilder.Entity<Message>(b =>
            {
                b.ToTable("messages");
                b.HasKey(m => m.Id).HasName("messages_pkey");
                b.Property(m => m.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(m => m.ChatId).HasColumnName("chat_id").IsRequired();
                b.Property(m => m.SenderId).HasColumnName("sender_id");
                b.Property(m => m.Kind).HasColumnName("kind").HasColumnType("message_kind").IsRequired();
                b.Property(m => m.Text).HasColumnName("text").IsRequired();
                b.Property(m => m.Special).HasColumnName("special");
                b.Property(m => m.Metadata).HasColumnName("metadata").HasColumnType("jsonb");
                b.Property(m => m.SentAt).HasColumnName("sent_at").IsRequired();

                b.HasOne(m => m.Chat)
                 .WithMany(c => c.Messages)
                 .HasForeignKey(m => m.ChatId)
                 .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(m => m.Sender)
                 .WithMany(u => u.SentMessages)
                 .HasForeignKey(m => m.SenderId)
                 .OnDelete(DeleteBehavior.SetNull);

                b.HasIndex(m => m.ChatId).HasDatabaseName("idx_messages_chat");
            });

            modelBuilder.Entity<ChatSuggestion>(b =>
            {
                b.ToTable("chat_suggestions");
                b.HasKey(cs => cs.Id).HasName("chat_suggestions_pkey");
                b.Property(cs => cs.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(cs => cs.ChatId).HasColumnName("chat_id").IsRequired();
                b.Property(cs => cs.Suggestion).HasColumnName("suggestion").IsRequired();

                b.HasOne(cs => cs.Chat)
                 .WithMany(c => c.Suggestions)
                 .HasForeignKey(cs => cs.ChatId)
                 .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<GameHistory>(b =>
            {
                b.ToTable("game_history");
                b.HasKey(gh => gh.Id).HasName("game_history_pkey");
                b.Property(gh => gh.Id).HasColumnName("id").ValueGeneratedOnAdd();
                b.Property(gh => gh.GameId).HasColumnName("game_id").IsRequired();
                b.Property(gh => gh.Snapshot).HasColumnName("snapshot").HasColumnType("jsonb").IsRequired();
                b.Property(gh => gh.CreatedAt).HasColumnName("created_at").IsRequired();

                b.HasOne(gh => gh.Game)
                 .WithMany(g => g.Histories)
                 .HasForeignKey(gh => gh.GameId)
                 .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}
