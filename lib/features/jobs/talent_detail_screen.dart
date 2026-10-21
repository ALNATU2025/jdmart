import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/jobs_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import 'job_widgets.dart';

/// A job seeker's public CV profile.
class TalentDetailScreen extends StatelessWidget {
  final String uid;
  const TalentDetailScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamView<TalentProfile?>(
      id: uid,
      create: () => context.read<JobRepository>().watchTalent(uid),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, t) {
        if (t == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile not available',
              message: 'This person has removed or hidden their CV profile.',
            ),
          );
        }
        final cat = JobsCatalog.category(t.categoryId);
        return Scaffold(
          appBar: AppBar(title: const Text('Talent profile')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: UserAvatar(name: t.name, imageUrl: t.photoUrl, radius: 42),
                      ),
                      const SizedBox(height: 12),
                      Text(t.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(t.headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill(cat.icon, cat.name),
                          _pill(Icons.location_on_outlined, t.city),
                          if (t.experienceYears > 0) _pill(Icons.timeline_rounded, '${t.experienceYears} yrs experience'),
                          if (t.openToWork) _pill(Icons.check_circle_rounded, 'Open to work', color: const Color(0xFF4ADE80)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Updated ${Fmt.ago(t.updatedAt)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              if (t.cvUrl != null)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                      onPressed: () async {
                        if (!await openExternal(t.cvUrl!) && context.mounted) {
                          showSnack(context, "Couldn't open the CV", error: true);
                        }
                      },
                      icon: const Icon(Icons.description_rounded),
                      label: Text('View CV${t.cvName == null ? '' : ' • ${t.cvName}'}', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              if ((t.phone ?? '').isNotEmpty || t.email.isNotEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: InfoSection(
                    title: 'Contact ${t.name.split(' ').first}',
                    child: ContactActions(
                      phone: t.phone,
                      email: t.email,
                      whatsAppText: 'Hello ${t.name}, I found your CV on JDMart and would like to talk about a job.',
                    ),
                  ),
                ),
              if (t.summary.isNotEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: InfoSection(
                    title: 'Experience & about',
                    child: SelectableText(t.summary, style: const TextStyle(height: 1.55)),
                  ),
                ),
              if (t.skills.isNotEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: InfoSection(
                    title: 'Skills',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final s in t.skills) JobTag(s, color: AppColors.blue)],
                    ),
                  ),
                ),
              if (t.education.isNotEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: InfoSection(
                    title: 'Education & certificates',
                    child: SelectableText(t.education, style: const TextStyle(height: 1.55)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(IconData icon, String text, {Color color = Colors.white}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}
