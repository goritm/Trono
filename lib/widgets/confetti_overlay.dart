import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Zero-dependency celebratory confetti burst overlay in Trono's palette.
/// Always wrapped in [IgnorePointer] so controls underneath remain interactive.
class ConfettiBurstOverlay extends StatefulWidget {
  const ConfettiBurstOverlay({
    super.key,
    this.duration = const Duration(milliseconds: 2200),
    this.particleCount = 48,
    this.seed,
  });

  final Duration duration;
  final int particleCount;
  final int? seed;

  @override
  State<ConfettiBurstOverlay> createState() => _ConfettiBurstOverlayState();
}

class _ConfettiBurstOverlayState extends State<ConfettiBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  static const _palette = <Color>[
    TronoColors.terracotta,
    TronoColors.gold,
    TronoColors.obsidian,
    TronoColors.sage,
    TronoColors.lightBg,
  ];

  @override
  void initState() {
    super.initState();
    _particles = _generateParticles(widget.particleCount, widget.seed);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
  }

  static List<_ConfettiParticle> _generateParticles(int count, int? seed) {
    final rng = math.Random(seed);
    return List.generate(count, (i) {
      final angle = -math.pi * 0.15 - rng.nextDouble() * (math.pi * 0.70);
      final speed = 170.0 + rng.nextDouble() * 340.0;
      return _ConfettiParticle(
        color: _palette[i % _palette.length],
        originJitterX: (rng.nextDouble() - 0.5) * 44.0,
        originJitterY: (rng.nextDouble() - 0.5) * 24.0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - (60.0 + rng.nextDouble() * 110.0),
        gravity: 480.0 + rng.nextDouble() * 260.0,
        swayAmplitude: 10.0 + rng.nextDouble() * 22.0,
        swayFrequency: 2.0 + rng.nextDouble() * 3.5,
        swayPhase: rng.nextDouble() * math.pi * 2,
        width: 6.0 + rng.nextDouble() * 6.0,
        height: 9.0 + rng.nextDouble() * 7.0,
        initialRotation: rng.nextDouble() * math.pi * 2,
        spinSpeed: (rng.nextBool() ? 1 : -1) * (4.0 + rng.nextDouble() * 8.0),
        isCircle: i % 5 == 0,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isCompleted) {
              return const SizedBox.shrink();
            }
            return CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.color,
    required this.originJitterX,
    required this.originJitterY,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.swayPhase,
    required this.width,
    required this.height,
    required this.initialRotation,
    required this.spinSpeed,
    required this.isCircle,
  });

  final Color color;
  final double originJitterX;
  final double originJitterY;
  final double vx;
  final double vy;
  final double gravity;
  final double swayAmplitude;
  final double swayFrequency;
  final double swayPhase;
  final double width;
  final double height;
  final double initialRotation;
  final double spinSpeed;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    // Monotonic ease-out for crisp initial burst spread.
    final burstT = Curves.easeOut.transform(progress);
    final timeSec = progress * 2.2;

    // Smooth fade-out during the final 30% of the burst.
    final opacity = progress < 0.70
        ? 1.0
        : ((1.0 - progress) / 0.30).clamp(0.0, 1.0);

    final originX = size.width * 0.5;
    final originY = size.height * 0.34;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final sway =
          math.sin(timeSec * p.swayFrequency + p.swayPhase) * p.swayAmplitude;
      final x = originX + p.originJitterX + p.vx * burstT * 1.15 + sway * progress;
      final y = originY +
          p.originJitterY +
          p.vy * burstT * 0.85 +
          0.5 * p.gravity * timeSec * timeSec;

      if (y > size.height + 30 || x < -40 || x > size.width + 40) continue;

      final rotation = p.initialRotation + p.spinSpeed * timeSec;
      // Subtle 3D flutter scale on the ribbon width.
      final flutter = 0.45 + 0.55 * math.cos(rotation * 1.3).abs();

      paint.color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.width * 0.5, paint);
      } else {
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: p.width * flutter,
          height: p.height,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}
