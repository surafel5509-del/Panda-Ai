import 'package:intl/intl.dart';

/// Small formatting helpers used across the app.
class Formatters {
  Formatters._();

  static String duration(Duration? d) {
    if (d == null || d.inMilliseconds <= 0) return '—';
    final int totalSeconds = d.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String dateTime(DateTime dt) =>
      DateFormat('MMM d, yyyy · HH:mm').format(dt);

  static String relativeDate(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'[\s_-]+'))
        .where((String w) => w.isNotEmpty)
        .map((String w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Masks an API token for display: shows first 4 and last 4 characters.
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) return 'Not set';
    final String t = token.trim();
    if (t.length <= 8) return '••••••••';
    return '${t.substring(0, 4)}••••••••${t.substring(t.length - 4)}';
  }
}
