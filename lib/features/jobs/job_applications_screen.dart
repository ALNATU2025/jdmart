import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'job_widgets.dart';

/// The employer's view of everyone who applied to a job.
class JobApplicationsScreen extends StatelessWidget {
  final Job job;
  const JobApplicationsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid) ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('Applicants • ${job.title}', overflow: TextOverflow.ellipsis)),
      body: StreamView<List<JobApplication>>(
        id: '${job.id}-$uid',
        create: () => context.read<JobRepository>().applicationsFor(job.id, uid),
        loading: const ListSkeleton(),
        builder: (_, apps) {
          if (apps.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No applications yet',
              message: 'You will get a notification when someone applies.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => FadeSlideIn(
              key: ValueKey(apps[i].applicantId),
              delay: Motion.stagger(i),
              child: _ApplicantCard(job: job, app: apps[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final Job job;
  final JobApplication app;
  const _ApplicantCard({required this.job, required this.app});

  Future<void> _set(BuildContext context, ApplicationStatus s) async {
    final err = await runWithProgress(
        context, () => context.read<JobRepository>().setApplicationStatus(job.id, app.applicantId, s));
    if (context.mounted && err != null) showSnack(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final color = applicationColor(app.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: app.applicantName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.applicantName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Applied ${Fmt.ago(app.createdAt)}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ),
              JobTag(app.status.label, color: color),
            ],
          ),
          if (app.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.greyLight, borderRadius: BorderRadius.circular(12)),
              child: Text(app.message, style: const TextStyle(height: 1.45)),
            ),
          ],
          if (app.cvUrl != null) ...[
            const SizedBox(height: 12),
            Pressable(
              onTap: () => openExternal(app.cvUrl!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(app.cvName ?? 'Open CV',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.orange),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ContactActions(
            phone: app.phone,
            email: app.email,
            whatsAppText: 'Hello ${app.applicantName}, about your application for "${job.title}" on JDMart.',
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Status:', style: TextStyle(color: AppColors.grey, fontSize: 13)),
              const Spacer(),
              if (app.status != ApplicationStatus.shortlisted)
                TextButton.icon(
                  onPressed: () => _set(context, ApplicationStatus.shortlisted),
                  icon: const Icon(Icons.star_rounded, size: 18, color: AppColors.success),
                  label: const Text('Shortlist', style: TextStyle(color: AppColors.success)),
                ),
              if (app.status != ApplicationStatus.rejected)
                TextButton(
                  onPressed: () => _set(context, ApplicationStatus.rejected),
                  child: const Text('Not selected', style: TextStyle(color: AppColors.grey)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
