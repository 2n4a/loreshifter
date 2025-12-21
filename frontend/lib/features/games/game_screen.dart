import 'dart:async';
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/services/interfaces/gameplay_service_interface.dart';
import '/features/auth/auth_cubit.dart';
import '/features/chat/domain/models/chat.dart';
import '/features/chat/domain/models/game_state.dart';
import '/features/chat/domain/models/message.dart';

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

  List<ChatSegment> _visiblePlayerChats() {
    final state = gameState;
    if (state == null) return [];
    final chats = state.playerChats;
    if (currentUserId == null) return [];
    if (state.game.hostId == currentUserId) {
      return chats;
    }
    return chats.where((chat) => chat.chatOwner == currentUserId).toList();
  }

  List<ChatSegment> _visibleAdviceChats() {
    final state = gameState;
    if (state == null) return [];
    final chats = state.adviceChats;
    if (currentUserId == null) return [];
    if (state.game.hostId == currentUserId) {
      return chats;
    }
    return chats.where((chat) => chat.chatOwner == currentUserId).toList();
  }

  List<ChatSegment> _orderedChats() {
    final state = gameState;
    if (state == null) return [];
    final chats = <ChatSegment>[];
    if (state.gameChat != null) {
      chats.add(state.gameChat!);
    }
    if (state.characterCreationChat != null) {
      chats.add(state.characterCreationChat!);
    }
    chats.addAll(_visiblePlayerChats());
    chats.addAll(_visibleAdviceChats());
    return chats;
  }

  int? _getChatIdForTab(int index) {
    final chats = _orderedChats();
    if (index < 0 || index >= chats.length) return null;
    return chats[index].chatId;
  }

  ChatSegment? get currentChat {
    final chats = _orderedChats();
    if (selectedTabIndex < 0 || selectedTabIndex >= chats.length) {
      return null;
    }
    final chat = chats[selectedTabIndex];
    return loadedChats[chat.chatId] ?? chat;
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

  @override
  List<Object?> get props => [gameId, currentUserId];
}

class GameScreenTabChanged extends GameScreenEvent {
  final int newIndex;

  GameScreenTabChanged(this.newIndex);

  @override
  List<Object?> get props => [newIndex];
}

class GameScreenMessageSent extends GameScreenEvent {
  final String text;

  GameScreenMessageSent(this.text);

  @override
  List<Object?> get props => [text];
}

class GameScreenWebSocketEventReceived extends GameScreenEvent {
  final Map<String, dynamic> event;

  GameScreenWebSocketEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class GameScreenRefreshed extends GameScreenEvent {}

class GameScreenBloc extends Bloc<GameScreenEvent, GameScreenState> {
  final GameplayService _gameplayService;
  final int _gameId;
  StreamSubscription? _wsSubscription;

  GameScreenBloc({
    required GameplayService gameplayService,
    required int gameId,
  })  : _gameplayService = gameplayService,
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
        errorMessage: null,
      ),
    );

    try {
      final gameState = await _gameplayService.getGameState(_gameId);
      emit(
        state.copyWith(
          status: GameScreenStatus.success,
          gameState: gameState,
        ),
      );

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
    final chatId = state._getChatIdForTab(event.newIndex);
    emit(state.copyWith(selectedTabIndex: event.newIndex));

    if (chatId == null) {
      return;
    }

    try {
      final chat = await _gameplayService.getChatSegment(_gameId, chatId);
      final newChats = Map<int, ChatSegment>.from(state.loadedChats);
      newChats[chatId] = chat;
      emit(state.copyWith(loadedChats: newChats));
    } catch (e) {
      developer.log('Error loading chat $chatId: $e');
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

    if (type == '_connection_state' && payload is Map<String, dynamic>) {
      final statusStr = payload['state'];
      ConnectionStatus status;
      if (statusStr == 'connected') {
        status = ConnectionStatus.connected;
      } else if (statusStr == 'reconnecting') {
        status = ConnectionStatus.reconnecting;
      } else {
        status = ConnectionStatus.disconnected;
      }

      emit(state.copyWith(connectionStatus: status));
      if (status == ConnectionStatus.connected) {
        add(GameScreenRefreshed());
      }
      return;
    }

    if (type == 'GameChatEvent' && payload is Map<String, dynamic>) {
      final chatId = payload['chat_id'] ?? payload['chatId'];
      if (chatId is int && state.loadedChats.containsKey(chatId)) {
        try {
          final chat = await _gameplayService.getChatSegment(_gameId, chatId);
          final newChats = Map<int, ChatSegment>.from(state.loadedChats);
          newChats[chatId] = chat;
          emit(state.copyWith(loadedChats: newChats));
        } catch (e) {
          developer.log('Error reloading chat on event: $e');
        }
      }
      return;
    }

    if ([
      'GameStatusEvent',
      'GameSettingsUpdateEvent',
      'PlayerJoinedEvent',
      'PlayerLeftEvent',
      'PlayerKickedEvent',
      'PlayerReadyEvent',
      'PlayerPromotedEvent',
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

class GameScreen extends StatelessWidget {
  final int gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authState = context.read<AuthCubit>().state;
        final currentUserId = authState is Authenticated ? authState.user.id : null;

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
    final safeCount = newCount < 1 ? 1 : newCount;
    if (safeCount != _previousTabCount) {
      final oldController = _tabController;
      oldController.removeListener(_onTabChanged);

      _tabController = TabController(
        length: safeCount,
        vsync: this,
        initialIndex: selectedIndex < safeCount ? selectedIndex : 0,
      );
      _tabController.addListener(_onTabChanged);
      _previousTabCount = safeCount;

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

  void _selectSuggestion(String suggestion) {
    _messageController.text = suggestion;
  }

  void _submitMessage(GameScreenState state) {
    if (state.isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<GameScreenBloc>().add(GameScreenMessageSent(text));
    _messageController.clear();
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
          final tabCount = state._orderedChats().length;
          _updateTabController(tabCount, state.selectedTabIndex);
        }

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
                  : _buildChatMessages(context, state, state.currentChat!),
            ),
            _buildSuggestions(context, state),
            _buildMessageInput(context, state),
          ],
        );
      },
    );
  }

  Widget _buildChatTabs(BuildContext context, GameScreenState state) {
    final cs = Theme.of(context).colorScheme;
    final gameState = state.gameState!;
    final tabs = <Tab>[];

    if (gameState.gameChat != null) {
      tabs.add(const Tab(text: 'Общий'));
    }
    if (gameState.characterCreationChat != null) {
      tabs.add(const Tab(text: 'Персонаж'));
    }

    final playerChats = state._visiblePlayerChats();
    for (final chat in playerChats) {
      final playerName = _playerName(gameState, chat.chatOwner, state.currentUserId);
      tabs.add(Tab(text: playerName));
    }

    final adviceChats = state._visibleAdviceChats();
    for (final chat in adviceChats) {
      final playerName = _playerName(gameState, chat.chatOwner, state.currentUserId);
      tabs.add(Tab(text: 'Советы $playerName'));
    }

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_tabController.length != tabs.length) {
      return const SizedBox.shrink();
    }

    return Container(
      color: cs.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: tabs,
      ),
    );
  }

  String _playerName(GameState gameState, int? userId, int? currentUserId) {
    if (userId == null) return 'Игрок';
    if (currentUserId != null && userId == currentUserId) {
      return 'Вы';
    }
    for (final player in gameState.game.players) {
      if (player.user.id == userId) {
        return player.user.name;
      }
    }
    return 'Игрок';
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
    GameScreenState state,
    ChatSegment chat,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: chat.messages.length,
      itemBuilder: (context, index) {
        final message = chat.messages[index];
        return _buildMessageBubble(context, state, message);
      },
    );
  }

  String? _lookupPlayerName(GameScreenState state, int senderId) {
    final gameState = state.gameState;
    if (gameState == null) return null;
    for (final player in gameState.game.players) {
      if (player.user.id == senderId) {
        return player.user.name;
      }
    }
    return null;
  }

  String _resolveSenderName(GameScreenState state, Message message) {
    final metadata = message.metadata;
    if (metadata != null) {
      final metaName = metadata['senderName'] ?? metadata['sender_name'];
      if (metaName is String && metaName.trim().isNotEmpty) {
        return metaName;
      }
    }

    if (message.senderId != null) {
      final playerName = _lookupPlayerName(state, message.senderId!);
      if (playerName != null) {
        return playerName;
      }
      if (message.senderId == state.currentUserId) {
        return 'Вы';
      }
    }

    switch (message.kind) {
      case MessageKind.system:
        return 'Система';
      case MessageKind.characterCreation:
        return 'Мастер персонажа';
      case MessageKind.generalInfo:
      case MessageKind.publicInfo:
      case MessageKind.privateInfo:
        return 'Мастер';
      case MessageKind.player:
        return 'Игрок';
    }
  }

  String _avatarInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  Widget _buildMessageBubble(
    BuildContext context,
    GameScreenState state,
    Message message,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isCurrentUser = message.senderId == state.currentUserId;
    final displayName = _resolveSenderName(state, message);
    final nameStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );

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

    if (message.sender.type == 'system') {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          child: Text(message.text, style: TextStyle(color: textColor)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Text(
                _avatarInitial(displayName),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!isCurrentUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color: borderColor,
                  width: borderColor == Colors.transparent ? 0 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(displayName, style: nameStyle),
                    ),
                  Text(message.text, style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Text(
                _avatarInitial(displayName),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, GameScreenState state) {
    final suggestions = state.currentChat?.suggestions ?? [];
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final suggestion in suggestions)
            ActionChip(
              label: Text(suggestion),
              onPressed: () => _selectSuggestion(suggestion),
            ),
        ],
      ),
    );
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
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                  final keys = HardwareKeyboard.instance.logicalKeysPressed;
                  final shiftDown = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                      keys.contains(LogicalKeyboardKey.shiftRight);
                  if (!shiftDown) {
                    _submitMessage(state);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
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
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitMessage(state),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: state.isSending
                ? null
                : () {
                    _submitMessage(state);
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
    final gameState = state.gameState;
    final chat = state.currentChat;
    if (gameState == null || chat == null || state.currentUserId == null) {
      return false;
    }

    if (gameState.game.hostId == state.currentUserId) {
      return true;
    }

    final interface = chat.interface.type;
    if (interface == ChatInterfaceType.readonly) {
      return false;
    }

    if (interface == ChatInterfaceType.foreign ||
        interface == ChatInterfaceType.foreignTimed) {
      if (chat.chatOwner != state.currentUserId) {
        return false;
      }
    }

    if (interface == ChatInterfaceType.timed ||
        interface == ChatInterfaceType.foreignTimed) {
      final deadline = chat.interface.deadline;
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        return false;
      }
    }

    return true;
  }
}
