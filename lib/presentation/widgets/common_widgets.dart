import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// PANDA logo mark: a monochrome panda glyph drawn with simple shapes.
class PandaMark extends StatelessWidget {
  final double size;
  const PandaMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.inverseBackground,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: CustomPaint(
        painter: _PandaPainter(p.inverseText),
      ),
    );
  }
}

class _PandaPainter extends CustomPainter {
  final Color color;
  _PandaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double w = size.width;
    final double h = size.height;
    // Ears
    canvas.drawCircle(Offset(w * 0.28, h * 0.26), w * 0.13, paint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.26), w * 0.13, paint);
    // Head
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.55), width: w * 0.62, height: h * 0.56),
      paint,
    );
    // Eye patches + eyes (cut out with background-colored circles is not
    // possible here, so draw eyes in the inverse of the mark color).
    final Paint eyePaint = Paint()..color = color;
    canvas.drawCircle(Offset(w * 0.38, h * 0.52), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.52), w * 0.055, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated audio waveform bars. When [active] is true the bars animate;
/// otherwise a static, deterministic pattern is drawn. Progress is shown
/// by filling bars up to [progress] (0..1).
class Waveform extends StatelessWidget {
  final double progress;
  final bool active;
  final double height;
  final int bars;
  const Waveform({
    super.key,
    this.progress = 0,
    this.active = false,
    this.height = 56,
    this.bars = 42,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          progress: progress.clamp(0.0, 1.0),
          active: active,
          playedColor: p.textPrimary,
          trackColor: p.border,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final bool active;
  final Color playedColor;
  final Color trackColor;
  _WaveformPainter({
    required this.progress,
    required this.active,
    required this.playedColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int count = 42;
    final double gap = 3;
    final double barWidth =
        math.max(2, (size.width - gap * (count - 1)) / count);
    final Paint played = Paint()..color = playedColor;
    final Paint track = Paint()..color = trackColor;
    final double playedX = size.width * progress;
    final int seed = active ? DateTime.now().millisecondsSinceEpoch ~/ 300 : 7;
    for (int i = 0; i < count; i++) {
      final double x = i * (barWidth + gap);
      final double wave = math.sin((i + seed) * 0.55) * 0.5 + 0.5;
      final double wave2 = math.sin((i * 0.7 + seed) * 1.3) * 0.5 + 0.5;
      final double h = size.height * (0.18 + 0.72 * (0.6 * wave + 0.4 * wave2));
      final Rect rect = Rect.fromLTWH(
          x, (size.height - h) / 2, barWidth, h);
      final RRect rrect = RRect.fromRectAndRadius(
          rect, Radius.circular(barWidth / 2));
      canvas.drawRRect(rrect, x < playedX ? played : track);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}

/// Live waveform that repaints while playing (used by the audio player bar).
class AnimatedWaveform extends StatelessWidget {
  final double progress;
  final bool playing;
  final double height;
  const AnimatedWaveform({
    super.key,
    required this.progress,
    required this.playing,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (!playing) {
      return Waveform(progress: progress, height: height);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: 600.ms,
      builder: (BuildContext context, double value, Widget? child) {
        return Waveform(progress: progress, active: true, height: height);
      },
    );
  }
}

/// Typing indicator: three pulsing dots.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    Widget dot(int index) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: p.textSecondary, shape: BoxShape.circle),
        )
            .animate(onPlay: (AnimationController c) => c.repeat(reverse: true))
            .scaleXY(begin: 0.6, end: 1.15, duration: 420.ms, delay: (index * 140).ms)
            .fadeIn(duration: 200.ms);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[dot(0), const SizedBox(width: 5), dot(1), const SizedBox(width: 5), dot(2)],
    );
  }
}

/// Elegant empty state with icon, title and optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.border, width: 1.5),
              ),
              child: Icon(icon, size: 34, color: p.textSecondary),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scaleXY(begin: 0.9, end: 1, duration: 400.ms),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header used across screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Inline error banner with optional retry.
class ErrorBanner extends StatelessWidget {
  final String message;
  final bool retryable;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  const ErrorBanner({
    super.key,
    required this.message,
    this.retryable = false,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 20, color: p.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (retryable && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.15, end: 0, duration: 250.ms);
  }
}

/// Shows a confirmation dialog. Returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Copies text and shows a snackbar confirmation.
void copyToClipboard(BuildContext context, String text, {String? message}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Copied to clipboard')),
  );
}

/// Formats a nullable duration for display.
String formatDuration(Duration? d) => Formatters.duration(d);
