import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/chat_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import '../auth/auth_guard.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: uid == null
          ? EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat with buyers & sellers',
              message: 'Sign in to ask questions, agree on a price and arrange delivery.',
              actionLabel: 'Sign in',
              onAction: () => ensureLoggedIn(context),
            )
          : StreamView<List<Conversation>>(
              id: uid,
              create: () => context.read<ChatRepository>().forUser(uid),
              builder: (_, all) {
                final convos = all.where((c) => c.lastMessage.isNotEmpty).toList();
                if (convos.isEmpty) {
                  return const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No messages yet',
                    message: 'Tap the chat button on any listing to message the seller.',
                  );
                }
                return ListView.separated(
                  itemCount: convos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
                  itemBuilder: (_, i) => _tile(context, convos[i], uid),
                );
              },
            ),
    );
  }

  Widget _tile(BuildContext context, Conversation c, String myId) {
    final unread = c.unreadFor(myId) > 0;
    return ListTile(
      tileColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(name: c.otherName(myId), radius: 26),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ProductImage(
                url: c.productImage,
                categoryId: 'other',
                width: 24,
                height: 24,
                iconSize: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(c.otherName(myId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
          ),
          Text(Fmt.ago(c.lastAt), style: const TextStyle(color: AppColors.grey, fontSize: 11)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.productTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.orange, fontSize: 11.5, fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.lastSenderId == myId ? 'You: ' : ''}${c.lastMessage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: unread ? AppColors.navy : AppColors.grey, fontSize: 13),
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id))),
    );
  }
}
