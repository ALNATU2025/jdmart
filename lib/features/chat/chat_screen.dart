import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/chat_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import '../catalog/product_detail_screen.dart';
import '../../core/theme/palette.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepository _repo = context.read<ChatRepository>();
  late final Stream<Conversation?> _convo = _repo.watch(widget.conversationId);
  late final Stream<List<ChatMessage>> _messages = _repo.messages(widget.conversationId);
  final _ctrl = TextEditingController();
  bool _sending = false;
  int _lastSeenCount = -1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send(Conversation c, String myId, [String? preset]) async {
    final text = preset ?? _ctrl.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.send(c, myId, text);
      if (preset == null) _ctrl.clear();
    } catch (_) {
      if (mounted) showSnack(context, "Message not sent. Check your connection.", error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _markRead(Conversation c, String myId) {
    if (c.unreadFor(myId) > 0) _repo.markRead(c.id, myId);
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.select<SessionProvider, String?>((s) => s.uid);
    if (myId == null) return Scaffold(appBar: AppBar());

    return StreamBuilder<Conversation?>(
      stream: _convo,
      builder: (_, cs) {
        final c = cs.data;
        if (c == null) {
          return Scaffold(appBar: AppBar(), body: cs.hasError ? ErrorView(error: cs.error) : const LoadingView());
        }
        _markRead(c, myId);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                UserAvatar(name: c.otherName(myId), radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(c.otherName(myId), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Material(
                color: context.surface,
                child: InkWell(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: c.productId))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      children: [
                        ProductImage(
                          url: c.productImage,
                          categoryId: 'other',
                          width: 44,
                          height: 44,
                          iconSize: 20,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(c.productTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.muted),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messages,
                  builder: (_, ms) {
                    final msgs = ms.data ?? const <ChatMessage>[];
                    if (msgs.length != _lastSeenCount) {
                      _lastSeenCount = msgs.length;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _markRead(c, myId);
                      });
                    }
                    if (msgs.isEmpty) return _emptyHint(c, myId);
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _bubble(msgs[i], msgs[i].senderId == myId),
                    );
                  },
                ),
              ),
              if (c.buyerId == myId && c.lastMessage.isEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: ['Is this still available?', 'What is your last price?', 'Do you deliver to my area?']
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(label: Text(t), onPressed: () => _send(c, myId, t)),
                            ))
                        .toList(),
                  ),
                ),
              _composer(c, myId),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyHint(Conversation c, String myId) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.waving_hand_rounded, size: 44, color: AppColors.orange),
              const SizedBox(height: 10),
              Text('Say kushe to ${c.otherName(myId)}!', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('For your safety, pay through JDMart checkout or on delivery — never send money in advance.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _bubble(ChatMessage m, bool mine) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          decoration: BoxDecoration(
            color: mine ? AppColors.blue : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SelectableText(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.navy, height: 1.35)),
              const SizedBox(height: 2),
              Text(Fmt.time(m.at), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : context.muted)),
            ],
          ),
        ),
      );

  Widget _composer(Conversation c, String myId) => SafeArea(
        top: false,
        child: Container(
          color: context.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    isDense: true,
                    counterText: '',
                    fillColor: context.soft,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(c, myId),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Send',
                style: IconButton.styleFrom(backgroundColor: AppColors.orange),
                onPressed: _sending ? null : () => _send(c, myId),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      );
}
