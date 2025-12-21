import 'dart:async';
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/services/interfaces/gameplay_service_interface.dart';
import '/features/auth/auth_cubit.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/game_state.dart';
import '/features/chat/domain/models/message.dart';

// --- BLOC & STATE ---

enum GameScreenStatus { initial, loading, success, failure }

enum ConnectionStatus { connecting, connected, disconnected, reconnecting }

class GameScreenState extends Equatable {
  final GameScreenStatus status;
  final ConnectionStatus connectionStatus;
  final GameState? gameState;
  final Map<int, ChatSegment> loadedChats;
  final int selectedTabIndex;
  final int? currentUserId;
  final String? errorMessage;
  final bool isSending;

  const GameScreenState({
    this.status = GameScreenStatus.initial,
    this.connectionStatus = ConnectionStatus.connecting,
    this.gameState,
    this.loadedChats = const {},
    this.selectedTabIndex = 0,
    this.currentUserId,
    this.errorMessage,
    this.isSending = false,
  });

  ChatSegment? get currentChat {
    if (gameState == null) return null;
    final chatId = _getChatIdForTab(selectedTabIndex);
    if (chatId == null) return null;
    return loadedChats[chatId];
  }

  int? _getChatIdForTab(int index) {
    if (gameState == null) return null;
    if (index == 0) {
      // General chat (Lobby chat)
      return gameState!.gameChat?.chatId;
    } else if (index == 1) {
      // Main Game Chat (Shared)
      // We assume the first player chat is the shared one, or the backend handles it.
      return gameState!.playerChats.isNotEmpty ? gameState!.playerChats.first.chatId : null;
    } else {
      // Advice chats (Personal Chats)
      final adviceIndex = index - 2;
      if (adviceIndex >= 0 && adviceIndex < gameState!.adviceChats.length) {
        return gameState!.adviceChats[adviceIndex].chatId;
      }
    }
    return null;
  }

  GameScreenState copyWith({
    GameScreenStatus? status,
    ConnectionStatus? connectionStatus,
    GameState? gameState,
    Map<int, ChatSegment>? loadedChats,
    int? selectedTabIndex,
    int? currentUserId,
    String? errorMessage,
    bool? isSending,
  }) {
    return GameScreenState(
      status: status ?? this.status,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      gameState: gameState ?? this.gameState,
      loadedChats: loadedChats ?? this.loadedChats,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: errorMessage,
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props => [
    status,
    connectionStatus,
    gameState,
    loadedChats,
    selectedTabIndex,
    currentUserId,
    errorMessage,
    isSending,
  ];
}

abstract class GameScreenEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameScreenInitialized extends GameScreenEvent {
  final int gameId;
  final int? currentUserId;
  GameScreenInitialized(this.gameId, this.currentUserId);
}

class GameScreenTabChanged extends GameScreenEvent {
  final int newIndex;
  GameScreenTabChanged(this.newIndex);
}

class GameScreenMessageSent extends GameScreenEvent {
  final String text;
  GameScreenMessageSent(this.text);
}

class GameScreenWebSocketEventReceived extends GameScreenEvent {
  final Map<String, dynamic> event;
  GameScreenWebSocketEventReceived(this.event);
}

class GameScreenRefreshed extends GameScreenEvent {}

class GameScreenBloc extends Bloc<GameScreenEvent, GameScreenState> {
  final GameplayService _gameplayService;
  final int _gameId;
  StreamSubscription? _wsSubscription;

  GameScreenBloc({
    required GameplayService gameplayService,
    required int gameId,
  }) : _gameplayService = gameplayService,
       _gameId = gameId,
       super(const GameScreenState()) {
    on<GameScreenInitialized>(_onInitialized);
    on<GameScreenTabChanged>(_onTabChanged);
    on<GameScreenMessageSent>(_onMessageSent);
    on<GameScreenWebSocketEventReceived>(_onWebSocketEvent);
    on<GameScreenRefreshed>(_onRefreshed);
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    _gameplayService.disconnectWebSocket();
    return super.close();
  }

  Future<void> _onInitialized(
    GameScreenInitialized event,
    Emitter<GameScreenState> emit,
  ) async {
    emit(
      state.copyWith(
        status: GameScreenStatus.loading,
        currentUserId: event.currentUserId,
      ),
    );

    try {
      final gameState = await _gameplayService.getGameState(_gameId);
      emit(
        state.copyWith(status: GameScreenStatus.success, gameState: gameState),
      );

      // Load initial chat (tab 0)
      add(GameScreenTabChanged(0));

      _connectWebSocket();
    } catch (e) {
      emit(
        state.copyWith(
          status: GameScreenStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _connectWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = _gameplayService
        .connectWebSocket(_gameId)
        .listen(
          (event) => add(GameScreenWebSocketEventReceived(event)),
          onError: (error) {
            developer.log('WebSocket error: $error');
          },
        );
  }

  Future<void> _onTabChanged(
    GameScreenTabChanged event,
    Emitter<GameScreenState> emit,
  ) async {
    emit(state.copyWith(selectedTabIndex: event.newIndex));

    final chatId = state._getChatIdForTab(event.newIndex);
    if (chatId != null) {
      try {
        final chat = await _gameplayService.getChatSegment(_gameId, chatId);
        final newChats = Map<int, ChatSegment>.from(state.loadedChats);
        newChats[chatId] = chat;
        emit(state.copyWith(loadedChats: newChats));
      } catch (e) {
        developer.log('Error loading chat $chatId: $e');
      }
    }
  }

  Future<void> _onMessageSent(
    GameScreenMessageSent event,
    Emitter<GameScreenState> emit,
  ) async {
    final currentChat = state.currentChat;
    if (currentChat == null) return;

    emit(state.copyWith(isSending: true));
    try {
      await _gameplayService.sendMessage(
        _gameId,
        currentChat.chatId,
        event.text,
      );
      // Reload chat immediately
      final chat = await _gameplayService.getChatSegment(
        _gameId,
        currentChat.chatId,
      );
      final newChats = Map<int, ChatSegment>.from(state.loadedChats);
      newChats[currentChat.chatId] = chat;
      emit(state.copyWith(loadedChats: newChats, isSending: false));
    } catch (e) {
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: 'Failed to send message: $e',
        ),
      );
    }
  }

  Future<void> _onWebSocketEvent(
    GameScreenWebSocketEventReceived event,
    Emitter<GameScreenState> emit,
  ) async {
    final type = event.event['type'];
    final payload = event.event['payload'];

    if (type == '_connection_state') {
      final statusStr = payload['state'];
      ConnectionStatus status;
      if (statusStr == 'connected')
        status = ConnectionStatus.connected;
      else if (statusStr == 'reconnecting')
        status = ConnectionStatus.reconnecting;
      else
        status = ConnectionStatus.disconnected;

      emit(state.copyWith(connectionStatus: status));
      if (status == ConnectionStatus.connected) {
        add(GameScreenRefreshed());
      }
    } else if (type == 'GameChatEvent') {
      final chatId = payload['chat_id'];
      if (chatId != null) {
        // Reload this chat if it's loaded
        if (state.loadedChats.containsKey(chatId)) {
          try {
            final chat = await _gameplayService.getChatSegment(_gameId, chatId);
            final newChats = Map<int, ChatSegment>.from(state.loadedChats);
            newChats[chatId] = chat;
            emit(state.copyWith(loadedChats: newChats));
          } catch (e) {
            developer.log('Error reloading chat on event: $e');
          }
        }
      }
    } else if ([
      'GameStatusEvent',
      'PlayerJoinedEvent',
      'PlayerLeftEvent',
      'PlayerKickedEvent',
      'PlayerReadyEvent',
    ].contains(type)) {
      add(GameScreenRefreshed());
    }
  }

  Future<void> _onRefreshed(
    GameScreenRefreshed event,
    Emitter<GameScreenState> emit,
  ) async {
    try {
      final gameState = await _gameplayService.getGameState(_gameId);
      emit(state.copyWith(gameState: gameState));

      // Reload current chat too
      final currentChatId = state._getChatIdForTab(state.selectedTabIndex);
      if (currentChatId != null) {
        final chat = await _gameplayService.getChatSegment(
          _gameId,
          currentChatId,
        );
        final newChats = Map<int, ChatSegment>.from(state.loadedChats);
        newChats[currentChatId] = chat;
        emit(state.copyWith(loadedChats: newChats));
      }
    } catch (e) {
      developer.log('Error refreshing game: $e');
    }
  }
}

// --- WIDGET ---

class GameScreen extends StatelessWidget {
  final int gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authState = context.read<AuthCubit>().state;
        final currentUserId = authState is Authenticated
            ? authState.user.id
            : null;

        return GameScreenBloc(
          gameplayService: context.read<GameplayService>(),
          gameId: gameId,
        )..add(GameScreenInitialized(gameId, currentUserId));
      },
      child: const _GameScreenView(),
    );
  }
}

class _GameScreenView extends StatefulWidget {
  const _GameScreenView();

  @override
  State<_GameScreenView> createState() => _GameScreenViewState();
}

class _GameScreenViewState extends State<_GameScreenView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Track previous tab count to detect changes
  int _previousTabCount = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      context.read<GameScreenBloc>().add(
        GameScreenTabChanged(_tabController.index),
      );
    }
  }

  void _updateTabController(int newCount, int selectedIndex) {
    if (newCount != _previousTabCount) {
      final oldController = _tabController;
      oldController.removeListener(_onTabChanged);

      _tabController = TabController(
        length: newCount,
        vsync: this,
        initialIndex: selectedIndex < newCount ? selectedIndex : 0,
      );
      _tabController.addListener(_onTabChanged);
      _previousTabCount = newCount;

      // Dispose old controller after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });

      setState(() {});
    } else if (_tabController.index != selectedIndex) {
      _tabController.animateTo(selectedIndex);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameScreenBloc, GameScreenState>(
      listenWhen: (previous, current) =>
          previous.gameState != current.gameState ||
          previous.loadedChats != current.loadedChats ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }

        if (state.gameState != null) {
          // 1 General + 1 Game + N Advice Chats
          final tabCount = 1 + 1 + state.gameState!.adviceChats.length;
          _updateTabController(tabCount, state.selectedTabIndex);
        }

        // Scroll to bottom if chat changed or new messages
        if (state.currentChat != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }
      },
      child: Scaffold(appBar: _buildAppBar(context), body: _buildBody(context)),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: BlocBuilder<GameScreenBloc, GameScreenState>(
        buildWhen: (previous, current) =>
            previous.connectionStatus != current.connectionStatus ||
            previous.gameState != current.gameState,
        builder: (context, state) {
          return Row(
            children: [
              Text(state.gameState?.game.name ?? 'Игра'),
              if (state.connectionStatus == ConnectionStatus.reconnecting) ...[
                const SizedBox(width: 12),
                _buildReconnectingIndicator(context),
              ],
            ],
          );
        },
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/'),
        tooltip: 'На главную',
      ),
    );
  }

  Widget _buildReconnectingIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Переподключение...',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<GameScreenBloc, GameScreenState>(
      builder: (context, state) {
        if (state.status == GameScreenStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.gameState == null) {
          return const Center(child: Text('Не удалось загрузить игру'));
        }

        return Column(
          children: [
            _buildChatTabs(context, state),
            Expanded(
              child: state.currentChat == null
                  ? _buildEmptyChat(context)
                  : _buildChatMessages(
                      context,
                      state.currentChat!,
                      state.currentUserId,
                    ),
            ),
            if (state.currentChat != null) _buildSuggestions(context),
            _buildMessageInput(context, state),
          ],
        );
      },
    );
  }

  Widget _buildChatTabs(BuildContext context, GameScreenState state) {
    final cs = Theme.of(context).colorScheme;
    final gameState = state.gameState!;
    final tabCount = 1 + 1 + gameState.adviceChats.length;

    // Ensure controller length matches state
    if (_tabController.length != tabCount) {
      return const SizedBox.shrink(); // Wait for listener to update controller
    }

    return Container(
      color: cs.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [
          const Tab(text: 'Общий чат'),
          const Tab(text: 'Игровой чат'),
          ...gameState.adviceChats.map((adviceChat) {
            final playerName = _getPlayerName(gameState, adviceChat.chatOwner);
            return Tab(text: 'Советы $playerName');
          }),
        ],
      ),
    );
  }

  String _getPlayerName(GameState gameState, int? userId) {
    if (userId == null) return 'Игрок';
    final player = gameState.game.players
        .where((p) => p.user.id == userId)
        .firstOrNull;
    return player?.user.name ?? 'Игрок';
  }

  Widget _buildEmptyChat(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Загрузка чата...',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages(
    BuildContext context,
    ChatSegment chat,
    int? currentUserId,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: chat.messages.length,
      itemBuilder: (context, index) {
        final message = chat.messages[index];
        return _buildMessageBubble(context, message, currentUserId);
      },
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    Message message,
    int? currentUserId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isCurrentUser = message.senderId == currentUserId;

    Color bubbleColor;
    BorderRadius borderRadius;
    Color borderColor = Colors.transparent;
    Color textColor = cs.onSurface;

    if (message.sender.type == 'system') {
      bubbleColor = cs.surfaceContainerHighest;
      borderRadius = BorderRadius.circular(12);
      textColor = cs.onSurfaceVariant;
      borderColor = cs.outlineVariant;
    } else if (message.sender.type == 'assistant') {
      bubbleColor = cs.secondaryContainer;
      borderRadius = BorderRadius.circular(16);
      textColor = cs.onSecondaryContainer;
    } else if (isCurrentUser) {
      bubbleColor = cs.primaryContainer;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
      textColor = cs.onPrimaryContainer;
    } else {
      bubbleColor = cs.surfaceContainerHigh;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    return Align(
      alignment: message.sender.type == 'system'
          ? Alignment.center
          : (isCurrentUser ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.sender.type != 'system' && !isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.sender.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ),
            Text(message.text, style: TextStyle(color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    // Placeholder for suggestions if needed
    return const SizedBox.shrink();
  }

  Widget _buildMessageInput(BuildContext context, GameScreenState state) {
    final cs = Theme.of(context).colorScheme;
    final canWrite = _canWriteInCurrentChat(state);

    if (!canWrite) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: cs.surfaceContainer,
        child: Center(
          child: Text(
            'Вы не можете писать в этот чат',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Введите сообщение...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: state.isSending
                ? null
                : () {
                    final text = _messageController.text.trim();
                    if (text.isNotEmpty) {
                      context.read<GameScreenBloc>().add(
                        GameScreenMessageSent(text),
                      );
                      _messageController.clear();
                    }
                  },
            icon: state.isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  bool _canWriteInCurrentChat(GameScreenState state) {
    if (state.gameState == null ||
        state.currentChat == null ||
        state.currentUserId == null)
      return false;

    // Allow Host to write everywhere
    if (state.gameState!.game.hostId == state.currentUserId) {
      return true;
    }

    final currentPlayer = state.gameState!.game.players
        .where((p) => p.user.id == state.currentUserId)
        .firstOrNull;

    if (currentPlayer == null) return false;

    // Tab 0: General Chat (Everyone can write)
    if (state.selectedTabIndex == 0) {
      return true;
    }

    // Tab 1: Game Chat (Everyone can write)
    if (state.selectedTabIndex == 1) {
      return true;
    }

    // Advice Chats
    // Only the owner of the chat can write
    final chatOwnerId = state.currentChat!.chatOwner;
    return chatOwnerId == state.currentUserId;
  }
}
