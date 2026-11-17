import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/skills_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/skill_pro.dart';
import '../../data/repositories/skill_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../jobs/job_widgets.dart';
import 'skill_edit_screen.dart';

class SkillDetailScreen extends StatelessWidget {
  final String uid;
  const SkillDetailScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final repo = context.read<SkillRepository>();
    return Scaffold(
      body: StreamView<SkillPro?>(
        id: uid,
        create: () => repo.watch(uid),
        loading: const Center(child: CircularProgressIndicator()),
        builder: (context, p) {
          if (p == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.person_off_rounded,
                title: 'Profile not found',
                message: 'This person may have removed their skill profile.',
              ),
            );
          }
          final type = p.mainType;
          final mine = session.uid == p.id;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 250,
                foregroundColor: Colors.white,
                backgroundColor: type.color,
                actions: [
                  if (mine)
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SkillEditScreen(existing: p))),
                    ),
                  if (session.isAdmin && !mine)
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'verify') await repo.setVerified(p.id, !p.verified);
                        if (v == 'hide') await repo.setVisible(p.id, !p.visible);
                        if (context.mounted) showSnack(context, 'Updated');
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'verify', child: Text(p.verified ? 'Remove verified badge' : 'Mark as verified')),
                        PopupMenuItem(value: 'hide', child: Text(p.visible ? 'Hide from search' : 'Show in search')),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color.lerp(type.color, Colors.black, 0.35)!, type.color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -10,
                            child: Floating(
                              distance: 6,
                              child: Icon(type.icon, size: 150, color: Colors.white.withValues(alpha: 0.12)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: UserAvatar(name: p.name, imageUrl: p.photoUrl, uid: p.id, radius: 40),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                                    ),
                                    if (p.verified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                                    ],
                                  ],
                                ),
                                if (p.headline.isNotEmpty)
                                  Text(p.headline,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeSlideIn(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            JobTag(p.available ? 'Available now' : 'Busy at the moment',
                                color: p.available ? AppColors.success : AppColors.grey,
                                icon: p.available ? Icons.check_circle_rounded : Icons.schedule_rounded),
                            JobTag([if (p.area.isNotEmpty) p.area, p.city].join(', '),
                                color: AppColors.blue, icon: Icons.place_rounded),
                            if (p.experienceYears > 0)
                              JobTag('${p.experienceYears} yrs experience',
                                  color: AppColors.orange, icon: Icons.workspace_premium_rounded),
                          ],
                        ),
                      ),
                    ),
                    if (p.phone.isNotEmpty && !mine)
                      InfoSection(
                        title: 'Contact ${p.name.split(' ').first}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Fmt.display(p.phone), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            ContactActions(
                              phone: p.whatsApp ? p.phone : null,
                              whatsAppText: 'Hello ${p.name}, I found you on JDMart Find skills. Are you available?',
                            ),
                            if (!p.whatsApp) ...[
                              ElevatedButton.icon(
                                onPressed: () => openExternal('tel:${p.phone}'),
                                icon: const Icon(Icons.call_rounded),
                                label: const Text('Call'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    InfoSection(
                      title: 'Skills',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in p.skills)
                            Builder(builder: (_) {
                              final t = SkillsCatalog.byKey(SkillsCatalog.keyOf(s));
                              return JobTag(SkillsCatalog.label(s), color: t.color, icon: t.icon);
                            }),
                        ],
                      ),
                    ),
                    if (p.rate.isNotEmpty)
                      InfoSection(
                        title: 'Price',
                        child: Text(p.rate, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    if (p.about.isNotEmpty)
                      InfoSection(
                        title: 'About',
                        child: Text(p.about, style: TextStyle(color: context.ink, height: 1.5)),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'JDMart doesn\'t employ the people listed here. Agree the price before work starts, '
                      'and pay when you\'re happy with the job.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.muted, fontSize: 12, height: 1.4),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
