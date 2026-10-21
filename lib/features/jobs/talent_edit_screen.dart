import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/constants/jobs_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../../core/theme/palette.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Create or edit my CV / talent profile so employers can find and contact me.
class TalentEditScreen extends StatefulWidget {
  const TalentEditScreen({super.key});

  @override
  State<TalentEditScreen> createState() => _TalentEditScreenState();
}

class _TalentEditScreenState extends State<TalentEditScreen> {
  late final Future<TalentProfile?> _load =
      context.read<JobRepository>().getTalent(context.read<SessionProvider>().uid ?? '');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TalentProfile?>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(title: const Text('My CV profile')), body: const LoadingView());
        }
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(title: const Text('My CV profile')), body: ErrorView(error: snap.error));
        }
        return _TalentForm(existing: snap.data);
      },
    );
  }
}

class _TalentForm extends StatefulWidget {
  final TalentProfile? existing;
  const _TalentForm({this.existing});

  @override
  State<_TalentForm> createState() => _TalentFormState();
}

class _TalentFormState extends State<_TalentForm> {
  final _form = GlobalKey<FormState>();
  late final SessionProvider _session = context.read<SessionProvider>();

  late final _headline = TextEditingController(text: widget.existing?.headline ?? '');
  late final _years = TextEditingController(
      text: (widget.existing?.experienceYears ?? 0) > 0 ? '${widget.existing!.experienceYears}' : '');
  late final _skills = TextEditingController(text: widget.existing?.skills.join(', ') ?? '');
  late final _summary = TextEditingController(text: widget.existing?.summary ?? '');
  late final _education = TextEditingController(text: widget.existing?.education ?? '');
  late final _phone = TextEditingController(text: _initialPhone());
  late final _email = TextEditingController(text: widget.existing?.email ?? _session.email);
  late String _category = widget.existing?.categoryId ?? JobsCatalog.categories.first.id;
  late String _city = Catalog.safeCity(widget.existing?.city ?? _session.profile?.city);
  late bool _openToWork = widget.existing?.openToWork ?? true;
  late bool _visible = widget.existing?.visible ?? true;
  late String? _cvUrl = widget.existing?.cvUrl;
  late String? _cvName = widget.existing?.cvName;
  PickedDoc? _newCv;
  bool _saving = false;

  String _initialPhone() {
    final e = widget.existing;
    final p = e != null ? (e.phone ?? '') : _session.phone;
    return p.isEmpty ? '' : Fmt.display(p);
  }

  @override
  void dispose() {
    for (final c in [_headline, _years, _skills, _summary, _education, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCv() async {
    try {
      final f = await pickCvFile();
      if (f != null && mounted) setState(() => _newCv = f);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = _session.uid;
    final me = _session.profile;
    if (uid == null || me == null) return;
    setState(() => _saving = true);
    final repo = context.read<JobRepository>();
    try {
      var cvUrl = _cvUrl;
      var cvName = _cvName;
      final picked = _newCv;
      if (picked != null) {
        cvUrl = await repo.uploadCv(uid, picked.name, picked.bytes);
        cvName = picked.name;
      }
      final skills = _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => s.length > 30 ? s.substring(0, 30) : s)
          .take(20)
          .toList();
      final profile = TalentProfile(
        id: uid,
        name: me.name,
        headline: _headline.text,
        categoryId: _category,
        city: _city,
        skills: skills,
        summary: _summary.text,
        experienceYears: int.tryParse(_years.text.trim()) ?? 0,
        education: _education.text,
        phone: _phone.text.trim().isEmpty ? null : Fmt.e164(_phone.text),
        email: _email.text,
        cvUrl: cvUrl,
        cvName: cvName,
        photoUrl: me.avatarUrl,
        openToWork: _openToWork,
        visible: _visible,
        updatedAt: DateTime.now(),
      );
      await repo.saveTalent(profile, isNew: widget.existing == null);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, _visible ? 'Your CV profile is live — employers can now find you' : 'CV profile saved (hidden)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't save your profile. Please try again.", error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete your CV profile?',
        message: 'Employers will no longer find you in Find talent.',
        confirm: 'Delete',
        danger: true);
    if (!ok || !mounted) return;
    final uid = _session.uid;
    if (uid == null) return;
    final err = await runWithProgress(context, () => context.read<JobRepository>().deleteTalent(uid));
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
    } else {
      Navigator.pop(context);
      showSnack(context, 'CV profile deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget gap() => const SizedBox(height: 14);
    var i = 0;
    Widget item(Widget child) => FadeSlideIn(delay: Motion.stagger(i++, stepMs: 35, maxSteps: 12), child: child);
    final cvLabel = _newCv?.name ?? _cvName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My CV profile'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete profile',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            item(Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  UserAvatar(name: _session.profile?.name ?? '', imageUrl: _session.profile?.avatarUrl, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_session.profile?.name ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        const Text('Employers on JDMart can find this profile and contact you.',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            gap(),
            item(TextFormField(
              controller: _headline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Headline', hintText: 'e.g. Experienced driver with clean licence'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 4) return 'Describe yourself in a few words';
                if (t.length > 80) return 'Keep it under 80 characters';
                return null;
              },
            )),
            gap(),
            item(DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Field of work'),
              items: [
                for (final c in JobsCatalog.categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(children: [Icon(c.icon, size: 18, color: c.color), const SizedBox(width: 8), Text(c.name)]),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            )),
            gap(),
            item(Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _city,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Town'),
                    items: [for (final c in Catalog.cities) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _city = v ?? _city),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Years exp.'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      return (n == null || n < 0 || n > 60) ? '0–60' : null;
                    },
                  ),
                ),
              ],
            )),
            gap(),
            item(TextFormField(
              controller: _skills,
              decoration: const InputDecoration(
                labelText: 'Skills',
                hintText: 'Separate with commas: Excel, customer service, driving',
              ),
            )),
            gap(),
            item(TextFormField(
              controller: _summary,
              minLines: 4,
              maxLines: 10,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Experience & about me',
                hintText: 'Where you worked, what you did, what you are good at',
                alignLabelWithHint: true,
              ),
            )),
            gap(),
            item(TextFormField(
              controller: _education,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Education & certificates', alignLabelWithHint: true),
            )),
            gap(),
            item(TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone / WhatsApp for employers', hintText: '076 123456'),
              validator: (v) => (v ?? '').trim().isEmpty ? null : Fmt.validatePhone(v),
            )),
            gap(),
            item(TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email for employers'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return (t.length > 100 || !_emailRe.hasMatch(t)) ? 'Enter a valid email' : null;
              },
            )),
            gap(),
            item(Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('CV file', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('PDF or Word, up to 5 MB.', style: TextStyle(color: context.muted, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  if (cvLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: context.orangeTint, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.description_rounded, color: AppColors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(cvLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          IconButton(
                            tooltip: 'Remove CV',
                            onPressed: () => setState(() {
                              _newCv = null;
                              _cvUrl = null;
                              _cvName = null;
                            }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickCv,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(cvLabel == null ? 'Upload CV' : 'Replace CV'),
                  ),
                ],
              ),
            )),
            gap(),
            item(Container(
              decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _openToWork,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) => setState(() => _openToWork = v),
                    title: const Text('Open to work'),
                    subtitle: const Text('Shows a green badge on your profile'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _visible,
                    activeThumbColor: AppColors.blue,
                    onChanged: (v) => setState(() => _visible = v),
                    title: const Text('Show in Find talent'),
                    subtitle: const Text('Turn off to hide your profile from employers'),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Save CV profile'),
            ),
          ],
        ),
      ),
    );
  }
}
