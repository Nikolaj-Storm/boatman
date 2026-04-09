import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/models/chat_message.dart';
import 'package:boatman/services/ai_service.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/photo_service.dart';
import 'package:boatman/screens/chunk_context_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  final _photoService = PhotoService();
  bool _isGenerating = false;
  String _streamingContent = '';
  CapturedPhoto? _pendingPhoto; // Photo staged for sending

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingPhoto == null) return;
    if (_isGenerating) return;

    final appState = context.read<AppState>();
    final aiService = context.read<AiService>();
    final db = context.read<DatabaseService>();
    final boat = appState.activeBoat;

    if (boat == null) return;

    // Build message content with photo context
    final photo = _pendingPhoto;
    String messageContent = text;
    String? imagePath;
    String? imageAnalysis;

    if (photo != null) {
      imagePath = photo.path;
      imageAnalysis = PhotoService.buildPhotoPromptContext();
      if (text.isEmpty) {
        messageContent = 'What can you tell me about this? [photo attached]';
      }
    }

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: messageContent,
      imagePath: imagePath,
      imageAnalysis: imageAnalysis,
    );

    setState(() {
      _messages.add(userMsg);
      _messageController.clear();
      _pendingPhoto = null;
      _isGenerating = true;
      _streamingContent = '';
    });

    _scrollToBottom();

    // Build the query with image context for the AI
    final aiQuery = imageAnalysis != null
        ? '$messageContent\n\n$imageAnalysis'
        : messageContent;

    try {
      final stream = aiService.chatStream(
        userMessage: aiQuery,
        boat: boat,
        db: db,
        conversationHistory: _messages
            .take(10)
            .map((m) => '${m.role}: ${m.content}')
            .toList(),
      );

      await for (final token in stream) {
        setState(() {
          _streamingContent += token;
        });
        _scrollToBottom();
      }

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

  Future<void> _takePhoto() async {
    final photo = await _photoService.takePhoto();
    if (photo != null) {
      setState(() => _pendingPhoto = photo);
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await _photoService.pickFromGallery();
    if (photo != null) {
      setState(() => _pendingPhoto = photo);
    }
  }

  void _removePhoto() {
    setState(() => _pendingPhoto = null);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, size: 28),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture the problem'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, size: 28),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
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

        // Pending photo preview
        if (_pendingPhoto != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_pendingPhoto!.path),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Photo attached',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          )),
                      Text(
                        'Describe what you see for best results',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _removePhoto,
                ),
              ],
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
                // Camera button — large for wet hands
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: _isGenerating ? null : _showPhotoOptions,
                    icon: Icon(
                      Icons.camera_alt,
                      color: _pendingPhoto != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: 'Attach photo',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _pendingPhoto != null
                          ? 'Describe what you see...'
                          : 'Describe your problem...',
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
      child: SingleChildScrollView(
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
              'Describe your problem or take a photo.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Photo prompt
            OutlinedButton.icon(
              onPressed: _showPhotoOptions,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take a photo of the problem'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 24),
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

  /// Build assistant message content, parsing [REF:sourceId:chunkIndex:label] into tappable links
  Widget _buildAssistantContent(String content) {
    // Split content by REF links
    final refPattern = RegExp(r'\[REF:([^:]+):(\d+):([^\]]+)\]');
    final parts = <Widget>[];
    int lastEnd = 0;

    for (final match in refPattern.allMatches(content)) {
      // Add markdown content before this link
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start);
        if (textBefore.trim().isNotEmpty) {
          parts.add(MarkdownBody(
            data: textBefore,
            styleSheet: MarkdownStyleSheet(
              p: Theme.of(context).textTheme.bodyMedium,
            ),
          ));
        }
      }

      // Add the tappable reference link
      final sourceId = match.group(1)!;
      final chunkIndex = int.parse(match.group(2)!);
      final label = match.group(3)!;

      parts.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () => _openChunkContext(sourceId, chunkIndex),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining content after the last link
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd);
      if (remaining.trim().isNotEmpty) {
        parts.add(MarkdownBody(
          data: remaining,
          styleSheet: MarkdownStyleSheet(
            p: Theme.of(context).textTheme.bodyMedium,
          ),
        ));
      }
    }

    // If no REF links found, just render as markdown
    if (parts.isEmpty) {
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts,
    );
  }

  void _openChunkContext(String sourceId, int chunkIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChunkContextScreen(
          sourceId: sourceId,
          focusChunkIndex: chunkIndex,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show attached image
                  if (message.hasImage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => _showFullImage(message.imagePath!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(message.imagePath!),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              color: Colors.grey.shade300,
                              child: const Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Message text
                  if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
                  else ...[
                    _buildAssistantContent(message.content),
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

  void _showFullImage(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Photo'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(path)),
            ),
          ),
        ),
      ),
    );
  }
}
