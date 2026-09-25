import '../l10n/strings.dart';

enum FeedbackCategory {
  idea,
  bug,
  praise,
  other,

  /// A tester protocol sent from test.html — not offered in the app's own
  /// feedback form.
  test;

  /// What users can pick in the in-app feedback form.
  static List<FeedbackCategory> get selectable =>
      values.where((c) => c != test).toList();

  static FeedbackCategory fromDb(String? v) => FeedbackCategory.values
      .firstWhere((c) => c.name == v, orElse: () => FeedbackCategory.other);

  String get label => t('feedback.category.$name');
}

DateTime _date(dynamic v) => DateTime.parse(v as String).toLocal();

class FeedbackItem {
  FeedbackItem({
    required this.id,
    required this.category,
    required this.message,
    required this.createdAt,
    required this.done,
    this.userName,
  });

  factory FeedbackItem.fromMap(Map<String, dynamic> m) => FeedbackItem(
    id: m['id'] as String,
    category: FeedbackCategory.fromDb(m['category'] as String?),
    message: m['message'] as String? ?? '',
    createdAt: _date(m['created_at']),
    done: m['status'] == 'done',
    userName:
        (m['profiles'] as Map?)?['full_name'] as String? ??
        m['author_name'] as String?,
  );

  final String id;
  final FeedbackCategory category;
  final String message;
  final DateTime createdAt;
  final bool done;

  /// The account's name, or the name a tester typed on test.html. Null
  /// when the account has since been deleted.
  final String? userName;
}

class ReportItem {
  ReportItem({
    required this.id,
    required this.reason,
    required this.createdAt,
    required this.done,
    this.details,
    this.reporterName,
    this.reportedName,
    this.reportedCount = 0,
    this.reportedSuspended = false,
    this.hasChat = false,
  });

  factory ReportItem.fromMap(Map<String, dynamic> m) {
    final reported = m['reported'] as Map?;
    return ReportItem(
      id: m['id'] as String,
      reason: m['reason'] as String? ?? '',
      details: m['details'] as String?,
      createdAt: _date(m['created_at']),
      done: m['status'] == 'done',
      reporterName: (m['reporter'] as Map?)?['full_name'] as String?,
      reportedName: reported?['full_name'] as String?,
      reportedCount: (reported?['report_count'] as num?)?.toInt() ?? 0,
      reportedSuspended: reported?['is_suspended'] as bool? ?? false,
      hasChat: m['group_id'] != null,
    );
  }

  final String id;
  final String reason;
  final String? details;
  final DateTime createdAt;
  final bool done;
  final String? reporterName;
  final String? reportedName;

  /// How often the reported person has been reported in total.
  final int reportedCount;

  /// Auto-hidden from matching after 3 reports.
  final bool reportedSuspended;

  /// The chat is kept for review (Supabase: groups/messages).
  final bool hasChat;
}

class AccountFeedbackItem {
  AccountFeedbackItem({
    required this.id,
    required this.isDeletion,
    required this.createdAt,
    this.reason,
    this.userName,
  });

  factory AccountFeedbackItem.fromMap(Map<String, dynamic> m, String? name) =>
      AccountFeedbackItem(
        id: m['id'] as String,
        isDeletion: m['action'] == 'delete',
        reason: m['reason'] as String?,
        createdAt: _date(m['created_at']),
        userName: name,
      );

  final String id;
  final bool isDeletion;
  final String? reason;
  final DateTime createdAt;
  final String? userName;
}
