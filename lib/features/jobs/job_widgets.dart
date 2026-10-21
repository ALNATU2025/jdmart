import 'package:flutter/material.dart';
import '../../core/constants/jobs_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/job.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import 'job_detail_screen.dart';
import 'talent_detail_screen.dart';
import '../../core/theme/palette.dart';

/// Rounded square with the company's initial, tinted by job category.
class JobLogo extends StatelessWidget {
  final String company;
  final String categoryId;
  final double size;
  const JobLogo({super.key, required this.company, required this.categoryId, this.size = 50});

  @override
  Widget build(BuildContext context) {
    final c = JobsCatalog.category(categoryId);
    final letter = company.trim().isEmpty ? '?' : company.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.color, Color.lerp(c.color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: c.color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Text(letter, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w800)),
    );
  }
}

/// Small coloured pill (job type, salary, skill, status...).
class JobTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const JobTag(this.text, {super.key, this.color = AppColors.blue, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

Color applicationColor(ApplicationStatus s) => switch (s) {
      ApplicationStatus.submitted => AppColors.blue,
      ApplicationStatus.shortlisted => AppColors.success,
      ApplicationStatus.rejected => context.muted,
    };

class JobCard extends StatelessWidget {
  final Job job;
  final Widget? trailing;
  const JobCard({super.key, required this.job, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cat = JobsCatalog.category(job.categoryId);
    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JobLogo(company: job.company, categoryId: job.categoryId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 2),
                  Text('${job.company} • ${job.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      JobTag(job.type, color: cat.color),
                      if (job.salary.isNotEmpty) JobTag(job.salary, color: AppColors.success, icon: Icons.payments_outlined),
                      JobTag(Fmt.ago(job.createdAt), color: context.muted, icon: Icons.schedule_rounded),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class TalentCard extends StatelessWidget {
  final TalentProfile talent;
  const TalentCard({super.key, required this.talent});

  @override
  Widget build(BuildContext context) {
    final t = talent;
    final cat = JobsCatalog.category(t.categoryId);
    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TalentDetailScreen(uid: t.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                UserAvatar(name: t.name, imageUrl: t.photoUrl, radius: 27),
                if (t.openToWork)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(t.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: context.ink)),
                  const SizedBox(height: 2),
                  Text(
                    '${t.city}${t.experienceYears > 0 ? ' • ${t.experienceYears} yrs experience' : ''}',
                    style: TextStyle(color: context.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      JobTag(cat.name, color: cat.color, icon: cat.icon),
                      for (final s in t.skills.take(3)) JobTag(s, color: context.ink),
                      if (t.cvUrl != null) const JobTag('CV', color: AppColors.orange, icon: Icons.description_outlined),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal "All + categories" filter.
class JobCategoryChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const JobCategoryChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String? id, String label, Color color) {
      final on = selected == id;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Pressable(
          scale: 0.94,
          onTap: () => onChanged(id),
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: on ? color : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: on ? color : context.line),
              boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
            ),
            child: Text(label,
                style: TextStyle(
                  color: on ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                )),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip(null, 'All', AppColors.blue),
          for (final c in JobsCatalog.categories) chip(c.id, c.name, c.color),
        ],
      ),
    );
  }
}

/// Section with a title, used on detail pages.
class InfoSection extends StatelessWidget {
  final String title;
  final Widget child;
  const InfoSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

/// Search box used on the jobs and talent tabs.
class JobSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const JobSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: softShadow()),
          child: TextField(
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(Icons.search_rounded, color: context.muted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      );
}
