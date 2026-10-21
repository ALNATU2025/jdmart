import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String myId, [String? preset]) {
    final text = preset ?? _ctrl.text;
    if (text.trim().isEmpty) return;
    context.read<ChatProvider>().send(widget.conversationId, myId, text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;
    final c = context.watch<ChatProvider>().byId(widget.conversationId);
    if (c == null) return Scaffold(appBar: AppBar());
    final p = context.watch<ProductProvider>().byId(c.productId);
    final msgs = c.messages.reversed.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().markRead(c.id, me.id);
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: c.otherName(me.id), radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.otherName(me.id),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                  const Text('Usually replies within an hour',
                      style: TextStyle(fontSize: 11, color: AppColors.grey, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (p != null)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      ProductImage(
                        path: p.images.isEmpty ? null : p.images.first,
                        categoryId: p.categoryId,
                        width: 44,
                        height: 44,
                        iconSize: 20,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(Fmt.price(p.price),
                                style: const TextStyle(
                                    color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: msgs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.waving_hand_rounded, size: 44, color: AppColors.orange),
                          const SizedBox(height: 10),
                          Text('Say kushe to ${c.otherName(me.id)}!',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('Never pay before you see the item or use JDMart checkout.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = m.senderId == me.id;
                      return Align(
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
                              Text(m.text,
                                  style: TextStyle(color: mine ? Colors.white : AppColors.navy, height: 1.35)),
                              const SizedBox(height: 2),
                              Text(Fmt.time(m.at),
                                  style: TextStyle(
                                      fontSize: 10, color: mine ? Colors.white70 : AppColors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (c.buyerId == me.id && c.messages.isEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: ['Is this still available?', 'What is your last price?', 'Do you deliver?']
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(label: Text(t), onPressed: () => _send(me.id, t)),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        isDense: true,
                        fillColor: AppColors.greyLight,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(me.id),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.orange),
                    onPressed: () => _send(me.id),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
