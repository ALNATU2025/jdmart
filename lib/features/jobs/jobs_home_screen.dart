import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../auth/auth_guard.dart';
import 'job_widgets.dart';
import 'my_jobs_screen.dart';
import 'post_job_screen.dart';
import 'talent_edit_screen.dart';

/// Jobs board: find jobs, find talent (CV profiles), post a job.
class JobsHomeScreen extends StatefulWidget {
  final int initialTab;
  const JobsHomeScreen({super.key, this.initialTab = 0});

  @override
  State<JobsHomeScreen> createState() => _JobsHomeScreenState();
}

class _JobsHomeScreenState extends State<JobsHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JDMart Jobs'),
        actions: [
          IconButton(
            tooltip: 'My jobs & applications',
            icon: const Icon(Icons.work_history_outlined),
            onPressed: () => _open(const MyJobsScreen()),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.orange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Find jobs'), Tab(text: 'Find talent')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [_JobsTab(), _TalentTab()]),
      floatingActionButton: AnimatedSwitcher(
        duration: Motion.medium,
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: _tabs.index == 0
            ? FloatingActionButton.extended(
                key: const ValueKey('post'),
                heroTag: 'fab-post-job',
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                onPressed: () => _open(const PostJobScreen()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Post a job', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            : FloatingActionButton.extended(
                key: const ValueKey('cv'),
                heroTag: 'fab-my-cv',
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                onPressed: () => _open(const TalentEditScreen()),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('My CV profile', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }
}

class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> with AutomaticKeepAliveClientMixin {
  String _q = '';
  String? _cat;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        JobSearchField(hint: 'Search job title, company or town', onChanged: (v) => setState(() => _q = v)),
        JobCategoryChips(selected: _cat, onChanged: (c) => setState(() => _cat = c)),
        const SizedBox(height: 6),
        Expanded(
          child: StreamView<List<Job>>(
            create: () => context.read<JobRepository>().openJobs(),
            loading: const ListSkeleton(),
            builder: (_, jobs) {
              final q = _q.trim().toLowerCase();
              final list = jobs
                  .where((j) =>
                      (_cat == null || j.categoryId == _cat) &&
                      (q.isEmpty || '${j.title} ${j.company} ${j.city} ${j.type}'.toLowerCase().contains(q)))
                  .toList();
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.work_outline_rounded,
                  title: jobs.isEmpty ? 'No jobs posted yet' : 'No matching jobs',
                  message: jobs.isEmpty
                      ? 'Hiring? Tap "Post a job" and reach job seekers across Sierra Leone.'
                      : 'Try another word or category.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => FadeSlideIn(
                  key: ValueKey(list[i].id),
                  delay: Motion.stagger(i),
                  child: JobCard(job: list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TalentTab extends StatefulWidget {
  const _TalentTab();

  @override
  State<_TalentTab> createState() => _TalentTabState();
}

class _TalentTabState extends State<_TalentTab> with AutomaticKeepAliveClientMixin {
  String _q = '';
  String? _cat;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    if (uid == null) {
      // Contact details of job seekers are only shown to signed-in members.
      return EmptyState(
        icon: Icons.groups_rounded,
        title: 'Find talent',
        message: 'Sign in to browse CVs of job seekers and contact them directly.',
        actionLabel: 'Sign in',
        onAction: () => ensureLoggedIn(context),
      );
    }
    return Column(
      children: [
        JobSearchField(hint: 'Search skills, names or towns', onChanged: (v) => setState(() => _q = v)),
        JobCategoryChips(selected: _cat, onChanged: (c) => setState(() => _cat = c)),
        const SizedBox(height: 6),
        Expanded(
          child: StreamView<List<TalentProfile>>(
            id: uid,
            create: () => context.read<JobRepository>().talent(),
            loading: const ListSkeleton(),
            builder: (_, people) {
              final q = _q.trim().toLowerCase();
              final list = people
                  .where((t) =>
                      (_cat == null || t.categoryId == _cat) &&
                      (q.isEmpty ||
                          '${t.name} ${t.headline} ${t.city} ${t.skills.join(' ')}'.toLowerCase().contains(q)))
                  .toList();
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.badge_outlined,
                  title: people.isEmpty ? 'No CVs yet' : 'No matching people',
                  message: people.isEmpty
                      ? 'Looking for work? Create your CV profile so employers can find and contact you.'
                      : 'Try another skill or category.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => FadeSlideIn(
                  key: ValueKey(list[i].id),
                  delay: Motion.stagger(i),
                  child: TalentCard(talent: list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
