import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// Frosted-glass rounded card used across the app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glow,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? glow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final glowColor = glow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glowColor == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 28,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glowing gradient button.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = const <Color>[NovaColors.purple, NovaColors.blue],
    this.height = 56,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> colors;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.first.withValues(alpha: 0.5),
              blurRadius: 26,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: NovaText.display(fontSize, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button with a faint glow.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: NovaColors.blue,
        side: BorderSide(color: NovaColors.blue.withValues(alpha: 0.6)),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Animated dark-navy background with drifting neon glows.
class NovaBackground extends StatefulWidget {
  const NovaBackground({super.key, required this.child});

  final Widget child;

  @override
  State<NovaBackground> createState() => _NovaBackgroundState();
}

class _NovaBackgroundState extends State<NovaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = reduceMotion(context);
    if (reduce && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduce && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(painter: _BackgroundPainter(_controller)),
        ),
        widget.child,
      ],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[NovaColors.navy, NovaColors.bgDeep],
        ).createShader(rect),
    );
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final a = animation.value * 2 * math.pi;
    glow(
      Offset(
        size.width * (0.2 + 0.1 * math.sin(a)),
        size.height * (0.15 + 0.05 * math.cos(a)),
      ),
      size.shortestSide * 0.8,
      NovaColors.purple,
    );
    glow(
      Offset(
        size.width * (0.85 - 0.1 * math.cos(a)),
        size.height * (0.8 + 0.05 * math.sin(a)),
      ),
      size.shortestSide * 0.9,
      NovaColors.blue,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => false;
}

Path novaStarPath(double outer, double inner, {int points = 4}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / points;
    final x = math.cos(angle) * radius;
    final y = math.sin(angle) * radius;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

/// The glowing nova star symbol.
class NovaMarkPainter extends CustomPainter {
  const NovaMarkPainter({this.glow = 1, this.rotation = 0});

  final double glow;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            NovaColors.purple.withValues(alpha: 0.55 * glow),
            NovaColors.blue.withValues(alpha: 0.18 * glow),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final star = novaStarPath(r * 0.7, r * 0.13);
    final bounds = star.getBounds();
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, NovaColors.blue, NovaColors.purple],
        ).createShader(bounds)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, r * 0.04),
    );
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NovaMarkPainter oldDelegate) =>
      oldDelegate.glow != glow || oldDelegate.rotation != rotation;
}

class NovaMark extends StatelessWidget {
  const NovaMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: NovaMarkPainter()),
      ),
    );
  }
}

/// Neon progress bar.
class NeonProgress extends StatelessWidget {
  const NeonProgress({super.key, required this.value, this.height = 10});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value < 0 ? 0 : (value > 1 ? 1 : value),
        minHeight: height,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        valueColor: const AlwaysStoppedAnimation<Color>(NovaColors.blue),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(text, style: NovaText.display(14, color: NovaColors.blue)),
    );
  }
}
