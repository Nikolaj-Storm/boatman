import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/models/chat_message.dart';
import 'package:boatman/services/ai_service.dart';
import 'package:boatman/services/database_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  bool _isGenerating = false;
  String _streamingContent = '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    final appState = context.read<AppState>();
    final aiService = context.read<AiService>();
    final db = context.read<DatabaseService>();
    final boat = appState.activeBoat;

    if (boat == null) return;

    // Add user message
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
    );

    setState(() {
      _messages.add(userMsg);
      _messageController.clear();
      _isGenerating = true;
      _streamingContent = '';
    });

    _scrollToBottom();

    // Generate AI response with streaming
    try {
      final stream = aiService.chatStream(
        userMessage: text,
        boat: boat,
        db: db,
        conversationHistory: _messages
            .take(10) // Last 10 messages for context
            .map((m) => '${m.role}: ${m.content}')
            .toList(),
      );

      await for (final token in stream) {
        setState(() {
          _streamingContent += token;
        });
        _scrollToBottom();
      }

      // Add completed assistant message
      final assistantMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: _streamingContent.trim(),
      );

      setState(() {
        _messages.add(assistantMsg);
        _streamingContent = '';
        _isGenerating = false;
      });

      // Save to database if we have an active session
      if (appState.activeChat != null) {
        await db.saveChatMessage(appState.activeChat!.id, userMsg);
        await db.saveChatMessage(appState.activeChat!.id, assistantMsg);
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: 'Error generating response: $e',
        ));
        _isGenerating = false;
        _streamingContent = '';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final boat = appState.activeBoat;

    return Column(
      children: [
        // Boat context bar
        if (boat != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              'Advising for: ${boat.name} ${boat.summary != boat.name ? "— ${boat.summary}" : ""}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),

        // Messages
        Expanded(
          child: _messages.isEmpty && _streamingContent.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_streamingContent.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _streamingContent.isNotEmpty) {
                      return _buildMessageBubble(
                        ChatMessage(
                          id: 'streaming',
                          role: 'assistant',
                          content: _streamingContent,
                        ),
                        isStreaming: true,
                      );
                    }
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Describe your problem...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Large send button for wet hands
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    onPressed: _isGenerating ? null : _sendMessage,
                    child: _isGenerating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'What needs fixing?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Describe your problem and I\'ll help you diagnose and fix it.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Quick-start suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Engine overheating', Icons.engineering),
                _buildSuggestionChip('Battery not charging', Icons.bolt),
                _buildSuggestionChip('Bilge pump not working', Icons.plumbing),
                _buildSuggestionChip('How to tie a bowline', Icons.sailing),
                _buildSuggestionChip('Gelcoat scratch repair', Icons.build),
                _buildSuggestionChip('Impeller replacement', Icons.engineering),
                _buildSuggestionChip('Winch maintenance', Icons.settings),
                _buildSuggestionChip('Man overboard procedure', Icons.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {bool isStreaming = false}) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.build, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
