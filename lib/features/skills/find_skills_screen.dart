import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/constants/skills_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../data/models/skill_pro.dart';
import '../../data/repositories/skill_repository.dart';
import '../../data/services/location_service.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../auth/auth_guard.dart';
import 'skill_detail_screen.dart';
import 'skill_edit_screen.dart';

/// Find a plumber, electrician, tailor… near you, and call them.
class FindSkillsScreen extends StatefulWidget {
  final String? initialSkill;
  const FindSkillsScreen({super.key, this.initialSkill});

  @override
  State<FindSkillsScreen> createState() => _FindSkillsScreenState();
}

class _FindSkillsScreenState extends State<FindSkillsScreen> {
  late String? _skill = widget.initialSkill;
  String? _city; // null = everywhere
  String _query = '';
  double? _myLat;
  double? _myLng;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<SessionProvider>().profile?.city;
    if (c != null && Catalog.cities.contains(c)) _city = c;
  }

  Future<void> _nearMe() async {
    if (_myLat != null) {
      setState(() => _myLat = _myLng = null);
      return;
    }
    setState(() => _locating = true);
    final err = await LocationService.ensurePermission();
    final pos = err == null ? await LocationService.current() : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
        _city = null; // distance matters more than the town now
      }
    });
    if (pos == null) showSnack(context, err ?? "Couldn't get your location. Turn on GPS and try again.", error: true);
  }

  double? _distance(SkillPro p) {
    if (_myLat == null || !p.hasLocation) return null;
    return LocationService.distance(_myLat!, _myLng!, p.lat!, p.lng!);
  }

  List<SkillPro> _arrange(List<SkillPro> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((p) {
      if (_city != null && p.city != _city) return false;
      if (q.isEmpty) return true;
      final hay = '${p.name} ${p.headline} ${p.skills.join(' ')} ${p.area} ${p.city}'.toLowerCase();
      return q.split(RegExp(r'\s+')).every(hay.contains);
    }).toList();
    list.sort((a, b) {
      final da = _distance(a), db = _distance(b);
      if (da != null || db != null) {
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }
      if (a.available != b.available) return a.available ? -1 : 1;
      if (a.verified != b.verified) return a.verified ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  void _offer() async {
    if (!await ensureLoggedIn(context) || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillEditScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<SessionProvider, bool>((s) => s.isLoggedIn);
    final skillName = _skill == null ? null : SkillsCatalog.byKey(_skill!).name;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find skills'),
        actions: [
          IconButton(
            tooltip: 'My skill profile',
            icon: const Icon(Icons.badge_outlined),
            onPressed: _offer,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'offer-skill',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: _offer,
        icon: const Icon(Icons.handyman_rounded),
        label: const Text('Offer your skills'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search: plumber, tailor, Wilberforce…',
                prefixIcon: Icon(Icons.search_rounded, color: context.muted),
              ),
            ),
          ),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SkillBubble(
                  label: 'All',
                  icon: Icons.apps_rounded,
                  color: AppColors.blue,
                  on: _skill == null,
                  onTap: () => setState(() => _skill = null),
                ),
                for (final s in SkillsCatalog.all)
                  _SkillBubble(
                    label: s.name.split(' ').first,
                    icon: s.icon,
                    color: s.color,
                    on: _skill == s.id,
                    onTap: () => setState(() => _skill = s.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_city),
                    initialValue: _city,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Sierra Leone')),
                      for (final c in Catalog.cities) DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _city = v),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  avatar: _locating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.my_location_rounded,
                          size: 18, color: _myLat != null ? Colors.white : context.brand),
                  label: const Text('Near me'),
                  selected: _myLat != null,
                  showCheckmark: false,
                  selectedColor: AppColors.blue,
                  labelStyle: TextStyle(
                      color: _myLat != null ? Colors.white : context.ink, fontWeight: FontWeight.w600),
                  onSelected: (_) => _nearMe(),
                ),
              ],
            ),
          ),
          Expanded(
            child: !loggedIn
                ? EmptyState(
                    icon: Icons.handyman_rounded,
                    title: 'Find skilled people near you',
                    message: 'Sign in to see plumbers, electricians, tailors and more in your area — and call them.',
                    actionLabel: 'Sign in',
                    onAction: () => ensureLoggedIn(context),
                  )
                : StreamView<List<SkillPro>>(
                    id: _skill ?? 'all',
                    create: () => context.read<SkillRepository>().search(skillKey: _skill),
                    loading: const ListSkeleton(),
                    builder: (context, all) {
                      final list = _arrange(all);
                      if (list.isEmpty) {
                        return EmptyState(
                          icon: _skill == null ? Icons.handyman_rounded : SkillsCatalog.byKey(_skill!).icon,
                          title: skillName == null ? 'No one here yet' : 'No ${skillName.toLowerCase()} found yet',
                          message: _city == null
                              ? 'Be the first! Offer your skills so people can find and call you.'
                              : 'Try "All Sierra Leone", or offer your own skills in $_city.',
                          actionLabel: 'Offer your skills',
                          onAction: _offer,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                        itemCount: list.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '${list.length} ${list.length == 1 ? 'person' : 'people'}'
                                '${_myLat != null ? ' • nearest first' : _city != null ? ' in $_city' : ''}',
                                style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          final p = list[i - 1];
                          return FadeSlideIn(
                            key: ValueKey(p.id),
                            delay: Motion.stagger(i - 1),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SkillCard(pro: p, distance: _distance(p)),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SkillBubble extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  const _SkillBubble({required this.label, required this.icon, required this.color, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: 72,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: Motion.medium,
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: on ? LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!]) : null,
                  color: on ? null : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : null,
                ),
                child: Icon(icon, color: on ? Colors.white : color, size: 26),
              ),
              const SizedBox(height: 5),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        ),
      );
}

/// One skilled person in the results.
class SkillCard extends StatelessWidget {
  final SkillPro pro;
  final double? distance;
  const SkillCard({super.key, required this.pro, this.distance});

  @override
  Widget build(BuildContext context) {
    final p = pro;
    final type = p.mainType;
    final where = [if (p.area.isNotEmpty) p.area, p.city].join(', ');
    return Pressable(
      scale: 0.98,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SkillDetailScreen(uid: p.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    UserAvatar(name: p.name, imageUrl: p.photoUrl, uid: p.id, radius: 28),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: p.available ? AppColors.success : AppColors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.surface, width: 2.5),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                          ),
                          if (p.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: AppColors.blue, size: 17),
                          ],
                        ],
                      ),
                      if (p.headline.isNotEmpty)
                        Text(p.headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: context.ink, height: 1.3)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, size: 14, color: context.muted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              distance != null ? '$where • ${LocationService.formatDistance(distance!)}' : where,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: type.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(type.icon, color: type.color, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in p.skills.take(3)) _Tag(SkillsCatalog.label(s)),
                      if (p.skills.length > 3) _Tag('+${p.skills.length - 3}'),
                    ],
                  ),
                ),
                if (p.phone.isNotEmpty) ...[
                  _RoundAction(
                    icon: Icons.call_rounded,
                    color: AppColors.success,
                    onTap: () => openExternal('tel:${p.phone}'),
                  ),
                  if (p.whatsApp) ...[
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: () => openExternal(
                          'https://wa.me/${p.phone.replaceAll(RegExp(r'[^0-9]'), '')}?text='
                          '${Uri.encodeComponent('Hello ${p.name}, I found you on JDMart. Are you available?')}'),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: context.brand, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.88,
        haptic: true,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}
