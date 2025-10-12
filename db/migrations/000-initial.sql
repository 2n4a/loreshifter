CREATE TABLE IF NOT EXISTS meta (
    version INTEGER NOT NULL
);

INSERT INTO meta (version) VALUES (0);

CREATE TABLE data_protection_keys (
  id SERIAL PRIMARY KEY,
  friendly_name TEXT,
  xml TEXT NOT NULL,
  creation_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    auth_id INTEGER UNIQUE,
    created_at TIMESTAMPTZ NOT NULL,
    deleted BOOLEAN NOT NULL
);

CREATE TABLE worlds (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    public BOOLEAN NOT NULL,
    owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    description TEXT,
    data JSONB,
    created_at TIMESTAMPTZ NOT NULL,
    last_updated_at TIMESTAMPTZ NOT NULL,
    deleted BOOLEAN NOT NULL
);

CREATE TYPE game_status AS ENUM ('waiting', 'playing', 'finished', 'archived');

CREATE TABLE games (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    public BOOLEAN NOT NULL,
    world_id INTEGER NOT NULL REFERENCES worlds(id) ON DELETE CASCADE,
    host_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    max_players INTEGER NOT NULL,
    status game_status NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE game_players (
    game_id INTEGER REFERENCES games(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    is_ready BOOLEAN NOT NULL,
    is_host BOOLEAN NOT NULL,
    is_spectator BOOLEAN NOT NULL,
    is_joined BOOLEAN NOT NULL,
    joined_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (game_id, user_id)
);

CREATE TYPE chat_type AS ENUM ('room', 'character_creation', 'game', 'advice');
CREATE TYPE chat_interface_type AS ENUM ('readonly', 'foreign', 'full', 'timed', 'foreignTimed');

CREATE TABLE chats (
    id SERIAL PRIMARY KEY,
    game_id INTEGER REFERENCES games(id) ON DELETE CASCADE,
    chat_type chat_type NOT NULL,
    owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    interface_type chat_interface_type NOT NULL,
    deadline TIMESTAMPTZ
);

CREATE TYPE message_kind AS ENUM (
    'player', 'system', 'characterCreation', 'generalInfo', 'publicInfo', 'privateInfo'
);

CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    chat_id INTEGER REFERENCES chats(id) ON DELETE CASCADE,
    sender_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    kind message_kind NOT NULL,
    text TEXT NOT NULL,
    special TEXT,
    metadata JSONB,
    sent_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE chat_suggestions (
    id SERIAL PRIMARY KEY,
    chat_id INTEGER REFERENCES chats(id) ON DELETE CASCADE,
    suggestion TEXT NOT NULL
);

CREATE TABLE game_history (
    id SERIAL PRIMARY KEY,
    game_id INTEGER REFERENCES games(id) ON DELETE CASCADE,
    snapshot JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_worlds_owner ON worlds(owner_id);
CREATE INDEX idx_games_world ON games(world_id);
CREATE INDEX idx_games_host ON games(host_id);
CREATE INDEX idx_messages_chat ON messages(chat_id);
CREATE INDEX idx_chats_game ON chats(game_id);
CREATE INDEX idx_game_players_user ON game_players(user_id);
