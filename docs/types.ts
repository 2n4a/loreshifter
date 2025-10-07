/// Возвращается в случае ошибки в API
type ApiError = {
    /// Код ошибки
    code: string,
    /// Человекочитаемое описание ошибки
    message: string,
}

type Ping = {
    time: Date,
}

type Pong = {
    time: Date,
}

type User = {
    id: number,
    name: string,
    email?: string,
}

type World = {
    id: number,
    name: string,
    public: boolean,
    createdAt: Date,
    lastUpdatedAt: Date,
    owner: User,  // краткая информация
    description?: string,
    data?: any,
}

type Player = {
    user: User,
    isReady: boolean,
    isHost: boolean,
    isSpectator: boolean,
}

type GameStatus = "waiting" | "playing" | "finished" | "archived"

type Game = {
    id: number,
    code: string,
    public: boolean,
    name: string,
    world: World,
    hostId: number,
    players: Player[],
    createdAt: Date,
    maxPlayers: number,
    status: GameStatus,
}

type NewGame = {
    public: boolean,
    name?: string,
    worldId: number,
    maxPlayers?: number,
}

type GameUpdate = {
    public?: boolean,
    name?: string,
    worldId?: number,
    hostId?: number,
    maxPlayers?: number,
}

type GameStateBase = {
    game: Game,
    status: GameStatus,
}

type MessageOut = {
    text: string,
    special: string,
    metadata: any,
}

type Ready = {
    isReady: boolean,
}

type MessageKind = "player" | "system" | "characterCreation" | "generalInfo" | "publicInfo" | "privateInfo"

type Message = {
    id: number,
    chatId: number,
    senderId?: number,
    kind: MessageKind,
    text: string,
    special: string,
    sentAt: Date,
    metadata: any,
}

type ChatInterface = {
    // Тип взаимодействия с пользователем
    // readonly - пользователь только читает сообщения (но поле ввода доступно - их можно будет отправлять позже)
    // foreign - какой-то другой игрок может писать в чат, а игрок нет
    // full - полноценный чат, можно писать сообщения
    // timed - пользователь может отправить одно сообщение до конца времени
    // foreign-timed - другой пользователь может отправить одно сообщение до конца времени,
    type: "readonly" | "foreign" | "full" | "timed" | "foreignTimed",
    // Дата окончания времени для типа "*timed"
    deadline?: Date,
}

type ChatSegment = {
    chatId: number,
    // какому игроку принадлежит чат. Общий чат не принадлежит какому-либо игроку,
    // чаты создания персонажей уникальны для каждого игрока, и т.д.
    chatOwner?: number,
    messages: Message[],
    // Есть ли сообщения до первого сообщения в этом чале, или это начало истории
    previousId: number | null,
    // Есть ли сообщения после последнего сообщения в этом чале, или это конец истории
    nextId: number | null,
    // Список предложений для сообщения в этом чате
    suggestions: string[],
    interface: ChatInterface,
}

type GameStateWaiting = GameStateBase & {
    gameChat: ChatSegment,
    characterCreationChat: ChatSegment,
}

type GameStatePlaying = GameStateBase & {
    // здесь и везде далее чаты перечислены в том же порядке, что и игроки в 
    // поле players игры

    // чаты для игры
    playerChats: ChatSegment[],
    // чаты для наводящих вопросов
    adviceChats: ChatSegment[],
    gameChat: ChatSegment,
}

type GameStateFinished = GameStateBase & {
    playerChats: ChatSegment[],
    adviceChats: ChatSegment[],
    gameChat: ChatSegment,
}

type GameStateArchived = GameStateBase & {
    playerChats: ChatSegment[],
    adviceChats: ChatSegment[],
    gameChat: ChatSegment,
}

type GameState = GameStateWaiting | GameStatePlaying | GameStateFinished | GameStateArchived
