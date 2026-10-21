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
import '../../state/session_provider.dart';
import '../auth/auth_guard.dart';
import 'job_applications_screen.dart';
import 'job_widgets.dart';
import 'post_job_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid);
    return StreamView<Job?>(
      id: jobId,
      create: () => context.read<JobRepository>().watch(jobId),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, job) {
        if (job == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.work_off_outlined,
              title: 'Job not available',
              message: 'This job was removed by the employer.',
            ),
          );
        }
        final isOwner = uid == job.ownerId;
        return Scaffold(
          appBar: AppBar(title: const Text('Job details')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(child: _Header(job: job)),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: InfoSection(
                  title: 'About the job',
                  child: SelectableText(job.description, style: const TextStyle(height: 1.55, fontSize: 14)),
                ),
              ),
              if ((job.contactPhone ?? '').isNotEmpty || job.contactEmail.isNotEmpty)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: InfoSection(
                    title: 'Contact the employer',
                    child: ContactActions(
                      phone: job.contactPhone,
                      email: job.contactEmail,
                      whatsAppText: 'Hello, I saw your "${job.title}" job on JDMart.',
                    ),
                  ),
                ),
              if (isOwner) FadeSlideIn(delay: const Duration(milliseconds: 180), child: _OwnerPanel(job: job)),
            ],
          ),
          bottomNavigationBar: isOwner ? null : _ApplyBar(job: job),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Job job;
  const _Header({required this.job});

  @override
  Widget build(BuildContext context) {
    final cat = JobsCatalog.category(job.categoryId);
    Widget pill(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: JobLogo(company: job.company, categoryId: job.categoryId, size: 52),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.company,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(cat.name, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(job.title,
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            pill(Icons.work_outline_rounded, job.type),
            pill(Icons.location_on_outlined, job.city),
            if (job.salary.isNotEmpty) pill(Icons.payments_outlined, job.salary),
          ]),
          const SizedBox(height: 12),
          Text('Posted ${Fmt.ago(job.createdAt)} by ${job.ownerName}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (!job.isOpen) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(
                job.status == JobStatus.hidden
                    ? 'Hidden by JDMart moderators'
                    : 'This job is closed and no longer accepting applications',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerPanel extends StatelessWidget {
  final Job job;
  const _OwnerPanel({required this.job});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<JobRepository>();
    return InfoSection(
      title: 'Manage your job post',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => JobApplicationsScreen(job: job))),
            icon: const Icon(Icons.people_alt_rounded),
            label: Text('View applications (${job.applicationsCount})'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PostJobScreen(existing: job))),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              if (job.status != JobStatus.hidden)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final err = await runWithProgress(context, () => repo.setOpen(job.id, !job.isOpen));
                      if (context.mounted && err != null) showSnack(context, err, error: true);
                    },
                    icon: Icon(job.isOpen ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 18),
                    label: Text(job.isOpen ? 'Close' : 'Reopen'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Delete this job?',
                  message: 'The job and all its applications will be removed.',
                  confirm: 'Delete',
                  danger: true);
              if (!ok || !context.mounted) return;
              final err = await runWithProgress(context, () => repo.delete(job.id));
              if (!context.mounted) return;
              if (err != null) {
                showSnack(context, err, error: true);
              } else {
                Navigator.pop(context);
                showSnack(context, 'Job deleted');
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            label: const Text('Delete job', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar for job seekers: apply, or see the status of my application.
class _ApplyBar extends StatelessWidget {
  final Job job;
  const _ApplyBar({required this.job});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    Widget bar(Widget child) => Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16)],
          ),
          child: child,
        );

    Widget applyButton() => ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
          onPressed: job.isOpen
              ? () async {
                  if (!await ensureLoggedIn(context)) return;
                  if (context.mounted) showApplySheet(context, job);
                }
              : null,
          icon: const Icon(Icons.send_rounded),
          label: Text(job.isOpen ? 'Apply now' : 'Applications closed'),
        );

    if (uid == null) return bar(applyButton());

    return bar(StreamView<JobApplication?>(
      id: '${job.id}-$uid',
      create: () => context.read<JobRepository>().myApplication(job.id, uid),
      loading: const SizedBox(height: 52),
      builder: (context, app) {
        if (app == null) return applyButton();
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: applicationColor(app.status).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: applicationColor(app.status)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Applied ${Fmt.ago(app.createdAt)} • ${app.status.label}',
                          style: TextStyle(color: applicationColor(app.status), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Withdraw application?', message: 'The employer will no longer see it.', confirm: 'Withdraw');
                if (!ok || !context.mounted) return;
                final err = await runWithProgress(context, () => context.read<JobRepository>().withdraw(job.id, uid));
                if (context.mounted && err != null) showSnack(context, err, error: true);
              },
              child: const Text('Withdraw', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        );
      },
    ));
  }
}

/// Bottom sheet where a job seeker sends their application.
Future<void> showApplySheet(BuildContext context, Job job) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApplySheet(job: job),
    );

class _ApplySheet extends StatefulWidget {
  final Job job;
  const _ApplySheet({required this.job});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _form = GlobalKey<FormState>();
  late final SessionProvider _session = context.read<SessionProvider>();
  late final _name = TextEditingController(text: _session.profile?.name ?? '');
  late final _phone = TextEditingController(text: _session.phone.isEmpty ? '' : Fmt.display(_session.phone));
  late final _email = TextEditingController(text: _session.email);
  final _message = TextEditingController();
  TalentProfile? _talent;
  bool _useProfileCv = true;
  PickedDoc? _file;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final uid = _session.uid;
    if (uid != null) {
      context.read<JobRepository>().getTalent(uid).then((t) {
        if (mounted) setState(() => _talent = t);
      }).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final f = await pickCvFile();
      if (f != null && mounted) setState(() => _file = f);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final uid = _session.uid;
    if (uid == null) return;
    setState(() => _sending = true);
    final repo = context.read<JobRepository>();
    try {
      String? cvUrl;
      String? cvName;
      if (_file != null) {
        cvUrl = await repo.uploadCv(uid, _file!.name, _file!.bytes);
        cvName = _file!.name;
      } else if (_useProfileCv && _talent?.cvUrl != null) {
        cvUrl = _talent!.cvUrl;
        cvName = _talent!.cvName;
      }
      await repo.apply(
        job: widget.job,
        uid: uid,
        name: _name.text,
        phone: Fmt.e164(_phone.text),
        email: _email.text,
        message: _message.text,
        cvUrl: cvUrl,
        cvName: cvName,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Application sent to ${widget.job.company} 🎉');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSnack(context, "Couldn't send your application. Please try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileCv = _talent?.cvUrl != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Apply for ${widget.job.title}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(widget.job.company, style: const TextStyle(color: AppColors.grey)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number', hintText: '076 123456'),
                validator: Fmt.validatePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v ?? '').length > 100 ? 'Too long' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                minLines: 3,
                maxLines: 6,
                maxLength: 1500,
                decoration: const InputDecoration(
                  labelText: 'Message to the employer (optional)',
                  hintText: 'Tell them why you are a good fit',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              const Text('CV', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (_file != null)
                _CvRow(name: _file!.name, onRemove: () => setState(() => _file = null))
              else if (profileCv)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useProfileCv,
                  onChanged: (v) => setState(() => _useProfileCv = v ?? false),
                  title: Text('Attach my CV (${_talent!.cvName ?? 'CV'})'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_file == null ? 'Upload a CV (PDF or Word)' : 'Choose another file'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Send application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CvRow extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  const _CvRow({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.description_rounded, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded), tooltip: 'Remove'),
          ],
        ),
      );
}
