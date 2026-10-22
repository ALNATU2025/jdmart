import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/constants/jobs_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'job_detail_screen.dart';
import '../../core/theme/palette.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Create or edit a job post.
class PostJobScreen extends StatefulWidget {
  final Job? existing;
  const PostJobScreen({super.key, this.existing});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _form = GlobalKey<FormState>();
  late final SessionProvider _session = context.read<SessionProvider>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _company = TextEditingController(text: widget.existing?.company ?? '');
  late final _salary = TextEditingController(text: widget.existing?.salary ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _phone = TextEditingController(text: _initialPhone());
  late final _email = TextEditingController(text: widget.existing?.contactEmail ?? _session.email);
  late String _category = widget.existing?.categoryId ?? JobsCatalog.categories.first.id;
  late String _type = widget.existing?.type ?? JobsCatalog.types.first;
  late String _city = Catalog.safeCity(widget.existing?.city ?? _session.profile?.city);

  String _initialPhone() {
    final e = widget.existing;
    final p = e != null ? (e.contactPhone ?? '') : _session.phone;
    return p.isEmpty ? '' : Fmt.display(p);
  }
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _company, _salary, _description, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _len(String? v, int min, int max, String what) {
    final t = (v ?? '').trim();
    if (t.length < min) return min <= 1 ? 'Enter $what' : '$what must be at least $min characters';
    if (t.length > max) return '$what must be at most $max characters';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = _session.uid;
    final me = _session.profile;
    if (uid == null || me == null) return;
    setState(() => _saving = true);
    final draft = JobDraft(
      title: _title.text,
      company: _company.text,
      description: _description.text,
      categoryId: _category,
      type: _type,
      city: _city,
      salary: _salary.text,
      contactEmail: _email.text,
      contactPhone: _phone.text.trim().isEmpty ? null : Fmt.e164(_phone.text),
    );
    final repo = context.read<JobRepository>();
    try {
      final existing = widget.existing;
      if (existing == null) {
        final id = await repo.create(ownerId: uid, ownerName: me.name, draft: draft);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: id)));
        showSnack(context, 'Your job is live 🎉');
      } else {
        await repo.update(existing.id, draft);
        if (!mounted) return;
        Navigator.pop(context);
        showSnack(context, 'Job updated');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't save the job. Please check your connection and try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget gap() => const SizedBox(height: 14);
    var i = 0;
    Widget item(Widget child) => FadeSlideIn(delay: Motion.stagger(i++, stepMs: 35, maxSteps: 12), child: child);

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Post a job' : 'Edit job')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            item(Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: context.brand),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Clear titles and a salary range get more applicants. Posting is free.',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )),
            gap(),
            item(TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Job title', hintText: 'e.g. Sales Assistant'),
              validator: (v) => _len(v, 4, 80, 'Job title'),
            )),
            gap(),
            item(TextFormField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Company or employer name'),
              validator: (v) => _len(v, 2, 80, 'Company name'),
            )),
            gap(),
            item(DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in JobsCatalog.categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(children: [
                      Icon(c.icon, size: 18, color: c.color),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            )),
            gap(),
            item(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Job type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in JobsCatalog.types)
                      ChoiceChip(
                        label: Text(t),
                        selected: _type == t,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: _type == t ? Colors.white : context.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
              ],
            )),
            gap(),
            item(DropdownButtonFormField<String>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Location'),
              items: [for (final c in Catalog.cities) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _city = v ?? _city),
            )),
            gap(),
            item(TextFormField(
              controller: _salary,
              decoration: const InputDecoration(labelText: 'Salary (optional)', hintText: 'e.g. Le 3,000 – 4,500 / month'),
              validator: (v) => (v ?? '').trim().length > 60 ? 'Keep it under 60 characters' : null,
            )),
            gap(),
            item(TextFormField(
              controller: _description,
              minLines: 6,
              maxLines: 14,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Job description',
                hintText: 'Duties, requirements, working hours, how to apply…',
                alignLabelWithHint: true,
              ),
              validator: (v) => _len(v, 20, 4000, 'Description'),
            )),
            gap(),
            item(const Text('How applicants can reach you', style: TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            item(Text('Applicants can also apply inside the app. These details are shown on the job post.',
                style: TextStyle(color: context.muted, fontSize: 12.5))),
            gap(),
            item(TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone / WhatsApp (optional)', hintText: '076 123456'),
              validator: (v) => (v ?? '').trim().isEmpty ? null : Fmt.validatePhone(v),
            )),
            gap(),
            item(TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                if (t.length > 100 || !_emailRe.hasMatch(t)) return 'Enter a valid email';
                return null;
              },
            )),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(widget.existing == null ? 'Publish job' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
