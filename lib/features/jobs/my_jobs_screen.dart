import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'job_detail_screen.dart';
import 'job_widgets.dart';
import 'post_job_screen.dart';

/// My job posts (as an employer) and my applications (as a job seeker).
class MyJobsScreen extends StatelessWidget {
  final int initialTab;
  const MyJobsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid) ?? '';
    final repo = context.read<JobRepository>();
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My jobs'),
          bottom: const TabBar(
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.orange,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: 'My job posts'), Tab(text: 'My applications')],
          ),
        ),
        body: TabBarView(
          children: [
            StreamView<List<Job>>(
              id: uid,
              create: () => repo.mine(uid),
              loading: const ListSkeleton(),
              builder: (context, jobs) {
                if (jobs.isEmpty) {
                  return EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No job posts yet',
                    message: 'Hiring? Post a job and applications will appear here.',
                    actionLabel: 'Post a job',
                    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostJobScreen())),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final j = jobs[i];
                    return FadeSlideIn(
                      key: ValueKey(j.id),
                      delay: Motion.stagger(i),
                      child: JobCard(
                        job: j,
                        trailing: Column(
                          children: [
                            JobTag(
                              switch (j.status) {
                                JobStatus.open => 'Open',
                                JobStatus.closed => 'Closed',
                                JobStatus.hidden => 'Hidden',
                              },
                              color: j.isOpen ? AppColors.success : AppColors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text('${j.applicationsCount}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.blue)),
                            const Text('applied', style: TextStyle(fontSize: 11, color: AppColors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            StreamView<List<JobApplication>>(
              id: uid,
              create: () => repo.myApplications(uid),
              loading: const ListSkeleton(),
              builder: (context, apps) {
                if (apps.isEmpty) {
                  return const EmptyState(
                    icon: Icons.send_outlined,
                    title: 'No applications yet',
                    message: 'Jobs you apply for will appear here with their status.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: apps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final a = apps[i];
                    return FadeSlideIn(
                      key: ValueKey(a.jobId),
                      delay: Motion.stagger(i),
                      child: Pressable(
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: a.jobId))),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
                          child: Row(
                            children: [
                              JobLogo(company: a.company, categoryId: 'other', size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.jobTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${a.company} • applied ${Fmt.ago(a.createdAt)}',
                                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              JobTag(a.status.label, color: applicationColor(a.status)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
