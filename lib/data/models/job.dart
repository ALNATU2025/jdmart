import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/keywords.dart';
import 'firestore_helpers.dart';

enum JobStatus { open, closed, hidden }

JobStatus _jobStatus(dynamic v) => switch (v) {
      'closed' => JobStatus.closed,
      'hidden' => JobStatus.hidden,
      _ => JobStatus.open,
    };

/// jobs/{id} — a vacancy posted by a user who wants to hire.
class Job {
  final String id;
  final String title;
  final String company;
  final String description;
  final String categoryId;
  final String type;
  final String city;
  final String salary; // free text, e.g. "Le 3,000 / month" (may be empty)
  final String contactEmail;
  final String? contactPhone; // E.164 or null
  final String ownerId;
  final String ownerName;
  final JobStatus status;
  final int applicationsCount; // maintained by Cloud Functions
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.categoryId,
    required this.type,
    required this.city,
    this.salary = '',
    this.contactEmail = '',
    this.contactPhone,
    required this.ownerId,
    required this.ownerName,
    this.status = JobStatus.open,
    this.applicationsCount = 0,
    required this.createdAt,
  });

  bool get isOpen => status == JobStatus.open;

  factory Job.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Job(
      id: doc.id,
      title: (j['title'] ?? '') as String,
      company: (j['company'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      categoryId: (j['categoryId'] ?? 'other') as String,
      type: (j['type'] ?? 'Full-time') as String,
      city: (j['city'] ?? 'Freetown') as String,
      salary: (j['salary'] ?? '') as String,
      contactEmail: (j['contactEmail'] ?? '') as String,
      contactPhone: j['contactPhone'] as String?,
      ownerId: (j['ownerId'] ?? '') as String,
      ownerName: (j['ownerName'] ?? '') as String,
      status: _jobStatus(j['status']),
      applicationsCount: toInt(j['applicationsCount']),
      createdAt: tsToDate(j['createdAt']),
    );
  }
}

/// The editable fields of a job post.
class JobDraft {
  final String title;
  final String company;
  final String description;
  final String categoryId;
  final String type;
  final String city;
  final String salary;
  final String contactEmail;
  final String? contactPhone;

  const JobDraft({
    required this.title,
    required this.company,
    required this.description,
    required this.categoryId,
    required this.type,
    required this.city,
    required this.salary,
    required this.contactEmail,
    required this.contactPhone,
  });

  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'company': company.trim(),
        'description': description.trim(),
        'categoryId': categoryId,
        'type': type,
        'city': city,
        'salary': salary.trim(),
        'contactEmail': contactEmail.trim(),
        'contactPhone': contactPhone,
        'keywords': Keywords.build([title, company, city, type]),
      };
}

enum ApplicationStatus { submitted, shortlisted, rejected }

ApplicationStatus _appStatus(dynamic v) => switch (v) {
      'shortlisted' => ApplicationStatus.shortlisted,
      'rejected' => ApplicationStatus.rejected,
      _ => ApplicationStatus.submitted,
    };

extension ApplicationStatusX on ApplicationStatus {
  String get value => switch (this) {
        ApplicationStatus.submitted => 'new',
        ApplicationStatus.shortlisted => 'shortlisted',
        ApplicationStatus.rejected => 'rejected',
      };
  String get label => switch (this) {
        ApplicationStatus.submitted => 'Submitted',
        ApplicationStatus.shortlisted => 'Shortlisted',
        ApplicationStatus.rejected => 'Not selected',
      };
}

/// jobs/{jobId}/applications/{applicantId} — one application per person per job.
class JobApplication {
  final String jobId;
  final String jobTitle;
  final String company;
  final String ownerId;
  final String applicantId;
  final String applicantName;
  final String phone;
  final String email;
  final String message;
  final String? cvUrl;
  final String? cvName;
  final ApplicationStatus status;
  final DateTime createdAt;

  const JobApplication({
    required this.jobId,
    required this.jobTitle,
    required this.company,
    required this.ownerId,
    required this.applicantId,
    required this.applicantName,
    required this.phone,
    required this.email,
    required this.message,
    this.cvUrl,
    this.cvName,
    this.status = ApplicationStatus.submitted,
    required this.createdAt,
  });

  factory JobApplication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return JobApplication(
      jobId: (j['jobId'] ?? doc.reference.parent.parent?.id ?? '') as String,
      jobTitle: (j['jobTitle'] ?? '') as String,
      company: (j['company'] ?? '') as String,
      ownerId: (j['ownerId'] ?? '') as String,
      applicantId: (j['applicantId'] ?? doc.id) as String,
      applicantName: (j['applicantName'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      message: (j['message'] ?? '') as String,
      cvUrl: j['cvUrl'] as String?,
      cvName: j['cvName'] as String?,
      status: _appStatus(j['status']),
      createdAt: tsToDate(j['createdAt']),
    );
  }
}

/// talent/{uid} — a job seeker's public profile and CV, so employers can contact them.
class TalentProfile {
  final String id;
  final String name;
  final String headline;
  final String categoryId;
  final String city;
  final List<String> skills;
  final String summary;
  final int experienceYears;
  final String education;
  final String? phone; // E.164 or null
  final String email;
  final String? cvUrl;
  final String? cvName;
  final String? photoUrl;
  final bool openToWork;
  final bool visible;
  final DateTime updatedAt;

  const TalentProfile({
    required this.id,
    required this.name,
    required this.headline,
    required this.categoryId,
    required this.city,
    this.skills = const [],
    this.summary = '',
    this.experienceYears = 0,
    this.education = '',
    this.phone,
    this.email = '',
    this.cvUrl,
    this.cvName,
    this.photoUrl,
    this.openToWork = true,
    this.visible = true,
    required this.updatedAt,
  });

  factory TalentProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return TalentProfile(
      id: doc.id,
      name: (j['name'] ?? '') as String,
      headline: (j['headline'] ?? '') as String,
      categoryId: (j['categoryId'] ?? 'other') as String,
      city: (j['city'] ?? 'Freetown') as String,
      skills: toStringList(j['skills']),
      summary: (j['summary'] ?? '') as String,
      experienceYears: toInt(j['experienceYears']),
      education: (j['education'] ?? '') as String,
      phone: j['phone'] as String?,
      email: (j['email'] ?? '') as String,
      cvUrl: j['cvUrl'] as String?,
      cvName: j['cvName'] as String?,
      photoUrl: j['photoUrl'] as String?,
      openToWork: j['openToWork'] != false,
      visible: j['visible'] != false,
      updatedAt: tsToDate(j['updatedAt']),
    );
  }

  /// Fields written by the owner (timestamps are added by the repository).
  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'headline': headline.trim(),
        'categoryId': categoryId,
        'city': city,
        'skills': skills,
        'summary': summary.trim(),
        'experienceYears': experienceYears,
        'education': education.trim(),
        'phone': phone,
        'email': email.trim(),
        'cvUrl': cvUrl,
        'cvName': cvName,
        'photoUrl': photoUrl,
        'openToWork': openToWork,
        'visible': visible,
        'keywords': Keywords.build([name, headline, city, ...skills]),
      };
}
