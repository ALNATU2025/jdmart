import 'package:flutter/material.dart';

/// A trade or service people can offer on "Find skills".
class SkillType {
  final String id; // lowercase key stored in skillKeys
  final String name;
  final IconData icon;
  final Color color;
  const SkillType(this.id, this.name, this.icon, this.color);
}

class SkillsCatalog {
  static const all = <SkillType>[
    SkillType('plumber', 'Plumber', Icons.plumbing_rounded, Color(0xFF0EA5E9)),
    SkillType('electrician', 'Electrician', Icons.electrical_services_rounded, Color(0xFFF59E0B)),
    SkillType('carpenter', 'Carpenter', Icons.carpenter_rounded, Color(0xFF92400E)),
    SkillType('mason', 'Mason / Builder', Icons.foundation_rounded, Color(0xFF78716C)),
    SkillType('painter', 'Painter', Icons.format_paint_rounded, Color(0xFFEC4899)),
    SkillType('tiler', 'Tiler', Icons.grid_view_rounded, Color(0xFF0D9488)),
    SkillType('welder', 'Welder', Icons.local_fire_department_rounded, Color(0xFFEA580C)),
    SkillType('mechanic', 'Mechanic', Icons.car_repair_rounded, Color(0xFF475569)),
    SkillType('ac-repair', 'AC & fridge repair', Icons.ac_unit_rounded, Color(0xFF06B6D4)),
    SkillType('generator', 'Generator repair', Icons.bolt_rounded, Color(0xFFCA8A04)),
    SkillType('solar', 'Solar installer', Icons.solar_power_rounded, Color(0xFF16A34A)),
    SkillType('phone-repair', 'Phone repair', Icons.phone_android_rounded, Color(0xFF6366F1)),
    SkillType('computer', 'Computer / IT', Icons.computer_rounded, Color(0xFF2563EB)),
    SkillType('tailor', 'Tailor / Seamstress', Icons.content_cut_rounded, Color(0xFFDB2777)),
    SkillType('hair', 'Hairdresser / Barber', Icons.face_retouching_natural_rounded, Color(0xFF9333EA)),
    SkillType('makeup', 'Makeup artist', Icons.brush_rounded, Color(0xFFF43F5E)),
    SkillType('cleaner', 'Cleaner', Icons.cleaning_services_rounded, Color(0xFF14B8A6)),
    SkillType('laundry', 'Laundry', Icons.local_laundry_service_rounded, Color(0xFF3B82F6)),
    SkillType('cook', 'Cook / Caterer', Icons.restaurant_rounded, Color(0xFFF97316)),
    SkillType('driver', 'Driver', Icons.directions_car_rounded, Color(0xFF1E40AF)),
    SkillType('mover', 'Mover / Labourer', Icons.local_shipping_rounded, Color(0xFF64748B)),
    SkillType('gardener', 'Gardener', Icons.yard_rounded, Color(0xFF15803D)),
    SkillType('security', 'Security guard', Icons.security_rounded, Color(0xFF334155)),
    SkillType('tutor', 'Teacher / Tutor', Icons.school_rounded, Color(0xFF7C3AED)),
    SkillType('photographer', 'Photographer', Icons.photo_camera_rounded, Color(0xFF0F172A)),
    SkillType('events', 'DJ / Events', Icons.celebration_rounded, Color(0xFFD946EF)),
  ];

  static const _other = SkillType('other', 'Other skill', Icons.handyman_rounded, Color(0xFF0029A8));

  /// Key used for searching: lowercase words joined by '-'.
  static String keyOf(String name) {
    final t = name.trim().toLowerCase();
    for (final s in all) {
      if (s.id == t || s.name.toLowerCase() == t) return s.id;
    }
    return t.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static SkillType byKey(String key) => all.firstWhere((s) => s.id == key, orElse: () => _other);

  /// Display name for a stored skill (catalog name, or the person's own words).
  static String label(String skill) {
    final k = keyOf(skill);
    final t = all.where((s) => s.id == k);
    return t.isEmpty ? skill.trim() : t.first.name;
  }
}
