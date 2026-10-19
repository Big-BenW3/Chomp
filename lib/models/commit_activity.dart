/// Commit activity model — one bucket per day.
///
/// The backend buckets a repo's recent commits by local date and caps
/// each day's count, so the heatmap gets a stable, tiny payload.

library;

class CommitDay {
  /// Local commit date, `YYYY-MM-DD`.
  final String date;

  /// Commits on that day (capped server-side at 30).
  final int count;

  const CommitDay({required this.date, required this.count});

  factory CommitDay.fromJson(Map<String, dynamic> json) => CommitDay(
        date: json['date'] as String,
        count: json['count'] as int? ?? 0,
      );
}

/// A repo's commit activity plus the raw total for the window.
class CommitActivity {
  final List<CommitDay> activity;

  /// Total commits in the look-back window (uncapped).
  final int total;

  const CommitActivity({required this.activity, required this.total});

  factory CommitActivity.fromJson(Map<String, dynamic> json) =>
      CommitActivity(
        activity: (json['activity'] as List<dynamic>? ?? [])
            .map((e) => CommitDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
      );
}
