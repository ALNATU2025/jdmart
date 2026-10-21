import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_image.dart';
import 'auth/login_screen.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: me == null
          ? EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat with buyers & sellers',
              message: 'Sign in to ask questions, negotiate prices and arrange delivery.',
              actionLabel: 'Sign in',
              onAction: () => ensureLoggedIn(context),
            )
          : _list(context, me.id),
    );
  }

  Widget _list(BuildContext context, String myId) {
    final convos = context.watch<ChatProvider>().forUser(myId).where((c) => c.messages.isNotEmpty).toList();
    final products = context.watch<ProductProvider>();
    if (convos.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No messages yet',
        message: 'Tap the chat button on any product to message the seller.',
      );
    }
    return ListView.separated(
      itemCount: convos.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
      itemBuilder: (_, i) {
        final c = convos[i];
        final last = c.messages.last;
        final unread = context.read<ChatProvider>().isUnread(c, myId);
        final p = products.byId(c.productId);
        return ListTile(
          tileColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(name: c.otherName(myId), radius: 26),
              if (p != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ProductImage(
                      path: p.images.isEmpty ? null : p.images.first,
                      categoryId: p.categoryId,
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
                    style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
              ),
              Text(Fmt.ago(last.at), style: const TextStyle(color: AppColors.grey, fontSize: 11)),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.productTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.orange, fontSize: 11.5, fontWeight: FontWeight.w600)),
              Text(
                '${last.senderId == myId ? 'You: ' : ''}${last.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: unread ? AppColors.navy : AppColors.grey, fontSize: 13),
              ),
            ],
          ),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id))),
        );
      },
    );
  }
}
