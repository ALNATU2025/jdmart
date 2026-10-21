import 'package:flutter/material.dart';

class JobCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  const JobCategory(this.id, this.name, this.icon, this.color);
}

/// Job categories and types. Keep the ids in sync with firestore.rules.
class JobsCatalog {
  static const categories = <JobCategory>[
    JobCategory('sales', 'Sales & Marketing', Icons.campaign_rounded, Color(0xFFFB6401)),
    JobCategory('it', 'IT & Software', Icons.computer_rounded, Color(0xFF0029A8)),
    JobCategory('education', 'Education', Icons.school_rounded, Color(0xFF7C3AED)),
    JobCategory('health', 'Health & Care', Icons.medical_services_rounded, Color(0xFFDC2626)),
    JobCategory('hospitality', 'Hotels & Food', Icons.restaurant_rounded, Color(0xFFDB2777)),
    JobCategory('construction', 'Construction', Icons.construction_rounded, Color(0xFFB45309)),
    JobCategory('driving', 'Driving & Logistics', Icons.local_shipping_rounded, Color(0xFF334155)),
    JobCategory('finance', 'Finance & Admin', Icons.account_balance_rounded, Color(0xFF0D9488)),
    JobCategory('ngo', 'NGO & Development', Icons.volunteer_activism_rounded, Color(0xFF16A34A)),
    JobCategory('agric', 'Agriculture', Icons.agriculture_rounded, Color(0xFF65A30D)),
    JobCategory('domestic', 'Domestic & Cleaning', Icons.cleaning_services_rounded, Color(0xFF0EA5E9)),
    JobCategory('media', 'Media & Design', Icons.palette_rounded, Color(0xFFE11D48)),
    JobCategory('security', 'Security', Icons.security_rounded, Color(0xFF1E3A8A)),
    JobCategory('other', 'Other', Icons.work_outline_rounded, Color(0xFF6B7385)),
  ];

  static const types = ['Full-time', 'Part-time', 'Contract', 'Internship', 'Temporary', 'Volunteer'];

  static JobCategory category(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.last);
}
