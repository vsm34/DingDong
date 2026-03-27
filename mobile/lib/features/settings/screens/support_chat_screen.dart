import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../providers/providers.dart';

/// /settings/support — AI Support Chat screen.
/// Left-aligned assistant bubbles, right-aligned user bubbles, typing indicator.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  static const _maxMessages = 20;

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      role: 'assistant',
      content:
          "Hi! I'm DingDong Support. Ask me anything about setting up or using your DingDong device.",
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Check limit — user messages + assistant messages, subtract initial greeting
    final userMessageCount =
        _messages.where((m) => m.role == 'user').length;
    if (userMessageCount >= _maxMessages ~/ 2) return;

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _messages.add(const _ChatMessage(role: 'assistant', content: '', isTyping: true));
      _isSending = true;
    });
    _scrollToBottom();

    // Build history excluding the typing indicator
    final history = _messages
        .where((m) => !m.isTyping)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    String reply;
    try {
      reply = await ref.read(aiServiceProvider).sendSupportMessage(history);
    } catch (_) {
      reply = "Sorry, I'm having trouble connecting. Please try again.";
    }

    if (!mounted) return;

    setState(() {
      _messages.removeWhere((m) => m.isTyping);
      _messages.add(_ChatMessage(role: 'assistant', content: reply));
      _isSending = false;
    });

    if (reply.startsWith("Sorry, I'm having trouble")) {
      DDToast.error(context, 'Connection error — response shown in chat.');
    }

    _scrollToBottom();
  }

  bool get _atLimit {
    final userCount = _messages.where((m) => m.role == 'user').length;
    return userCount >= _maxMessages ~/ 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('DingDong Support', style: DDTypography.h3),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: DDSpacing.xl,
                vertical: DDSpacing.md,
              ),
              itemCount: _messages.length + (_atLimit ? 1 : 0),
              itemBuilder: (context, i) {
                if (_atLimit && i == _messages.length) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: DDSpacing.md),
                    child: Center(
                      child: Text(
                        'Conversation limit reached. Start a new chat.',
                        style: DDTypography.caption
                            .copyWith(color: DDColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),
          _BottomInput(
            controller: _inputController,
            onSend: _atLimit ? null : _sendMessage,
            enabled: !_isSending && !_atLimit,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  final bool isTyping;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.isTyping = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DDSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF355E3B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: DDSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: DDSpacing.md, vertical: DDSpacing.sm),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF355E3B)
                    : const Color(0xFFF4F6F1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : Radius.zero,
                  bottomRight: isUser
                      ? Radius.zero
                      : const Radius.circular(16),
                ),
              ),
              child: message.isTyping
                  ? const _TypingIndicator()
                  : isUser
                      ? Text(
                          message.content,
                          style: DDTypography.bodyM.copyWith(
                            color: Colors.white,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          shrinkWrap: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: DDTypography.bodyM.copyWith(
                              color: DDColors.textPrimary,
                            ),
                          ),
                        ),
            ),
          ),
          if (isUser) const SizedBox(width: DDSpacing.sm),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i * 0.2).clamp(0.0, 1.0);
            final opacity = phase < 0.5 ? phase * 2 : (1.0 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: const CircleAvatar(
                  radius: 3,
                  backgroundColor: Color(0xFF355E3B),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _BottomInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  final bool enabled;

  const _BottomInput({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DDColors.white,
        border: Border(
          top: BorderSide(color: DDColors.borderDefault, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DDSpacing.xl,
        DDSpacing.sm,
        DDSpacing.md,
        DDSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: DDTextField(
              label: '',
              controller: controller,
              hint: 'Ask a question...',
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? (_) => onSend?.call() : null,
            ),
          ),
          const SizedBox(width: DDSpacing.sm),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF355E3B)),
            onPressed: enabled ? onSend : null,
          ),
        ],
      ),
    );
  }
}
