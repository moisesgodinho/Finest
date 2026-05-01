import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FinancePetAvatar extends StatelessWidget {
  const FinancePetAvatar({
    required this.level,
    required this.progress,
    this.size = 148,
    this.showEnvironment = true,
    super.key,
  });

  final int level;
  final double progress;
  final double size;
  final bool showEnvironment;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _FinancePetAvatarPainter(
          level: level,
          progress: progress.clamp(0.0, 1.0).toDouble(),
          showEnvironment: showEnvironment,
        ),
      ),
    );
  }
}

class _FinancePetAvatarPainter extends CustomPainter {
  const _FinancePetAvatarPainter({
    required this.level,
    required this.progress,
    required this.showEnvironment,
  });

  final int level;
  final double progress;
  final bool showEnvironment;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    if (showEnvironment) {
      _paintEnvironment(canvas, size, unit);
    }

    if (level >= 4) {
      _paintAura(canvas, center, unit);
    }
    if (level >= 7 && level < 10) {
      _paintCape(canvas, center, unit);
    }
    if (level >= 3) {
      _paintBackpack(canvas, center, unit);
    }

    if (level <= 1) {
      _paintEgg(canvas, center, unit);
    } else {
      _paintPetBody(canvas, center, unit);
      if (level >= 5) {
        _paintLegs(canvas, center, unit);
      }
      if (level >= 8) {
        _paintBoots(canvas, center, unit);
      }
    }

    if (level >= 10) {
      _paintMysticHalo(canvas, center, unit);
    }
  }

  void _paintEnvironment(Canvas canvas, Size size, double unit) {
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEAF8EF),
          Color(0xFFCDEEDD),
        ],
      ).createShader(bgRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(unit * 0.24)),
      bgPaint,
    );

    final wavePaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.014;

    for (var i = 0; i < 4; i++) {
      final path = Path();
      final y = unit * (0.24 + i * 0.08);
      path.moveTo(unit * 0.12, y);
      path.cubicTo(
        unit * 0.34,
        y - unit * 0.12,
        unit * 0.58,
        y + unit * 0.16,
        unit * 0.90,
        y - unit * 0.04,
      );
      canvas.drawPath(path, wavePaint);
    }

    if (level >= 6) {
      final housePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.14);
      final roofPaint = Paint()
        ..color = AppColors.primaryDark.withValues(alpha: 0.14);
      final base = Rect.fromLTWH(
        unit * 0.10,
        unit * 0.56,
        unit * (level >= 9 ? 0.24 : 0.20),
        unit * 0.18,
      );
      final roof = Path()
        ..moveTo(base.left - unit * 0.03, base.top)
        ..lineTo(base.center.dx, base.top - unit * 0.10)
        ..lineTo(base.right + unit * 0.03, base.top)
        ..close();
      canvas.drawPath(roof, roofPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(base, Radius.circular(unit * 0.025)),
        housePaint,
      );

      if (level >= 9) {
        final towerPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.13);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(unit * 0.10, unit * 0.45, unit * 0.07, unit * 0.30),
            Radius.circular(unit * 0.018),
          ),
          towerPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(unit * 0.27, unit * 0.45, unit * 0.07, unit * 0.30),
            Radius.circular(unit * 0.018),
          ),
          towerPaint,
        );
      }
    }

    final groundPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, unit * 0.80),
        width: unit * 0.70,
        height: unit * 0.12,
      ),
      groundPaint,
    );
  }

  void _paintAura(Canvas canvas, Offset center, double unit) {
    final auraPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.035;

    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, unit * 0.04),
        width: unit * 0.70,
        height: unit * 0.70,
      ),
      -math.pi * 0.86,
      math.pi * (1.55 + progress * 0.20),
      false,
      auraPaint,
    );
  }

  void _paintCape(Canvas canvas, Offset center, double unit) {
    final capePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.26),
          AppColors.primaryDark.withValues(alpha: 0.36),
        ],
      ).createShader(
        Rect.fromCenter(
          center: center.translate(0, unit * 0.08),
          width: unit * 0.68,
          height: unit * 0.58,
        ),
      );
    final cape = Path()
      ..moveTo(center.dx - unit * 0.18, center.dy - unit * 0.12)
      ..quadraticBezierTo(
        center.dx - unit * 0.42,
        center.dy + unit * 0.24,
        center.dx - unit * 0.20,
        center.dy + unit * 0.40,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + unit * 0.28,
        center.dx + unit * 0.20,
        center.dy + unit * 0.40,
      )
      ..quadraticBezierTo(
        center.dx + unit * 0.42,
        center.dy + unit * 0.24,
        center.dx + unit * 0.18,
        center.dy - unit * 0.12,
      )
      ..close();
    canvas.drawPath(cape, capePaint);
  }

  void _paintBackpack(Canvas canvas, Offset center, double unit) {
    final bagPaint = Paint()
      ..color = const Color(0xFF3F8F75).withValues(alpha: 0.90);
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.012;

    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - unit * 0.38,
        center.dy + unit * 0.02,
        unit * 0.18,
        unit * 0.20,
      ),
      Radius.circular(unit * 0.04),
    );
    canvas.drawRRect(bag, bagPaint);
    canvas.drawRRect(bag, strokePaint);
  }

  void _paintEgg(Canvas canvas, Offset center, double unit) {
    final shellRect = Rect.fromCenter(
      center: center.translate(0, unit * 0.05),
      width: unit * 0.50,
      height: unit * 0.64,
    );
    final shellPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFDFF4E8),
        ],
      ).createShader(shellRect);
    canvas.drawOval(shellRect, shellPaint);

    final outlinePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018;
    canvas.drawOval(shellRect, outlinePaint);

    final crackPaint = Paint()
      ..color = AppColors.primaryDark.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.014
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final crack = Path()
      ..moveTo(center.dx - unit * 0.12, center.dy - unit * 0.10)
      ..lineTo(center.dx - unit * 0.03, center.dy - unit * 0.02)
      ..lineTo(center.dx - unit * 0.08, center.dy + unit * 0.08)
      ..lineTo(center.dx + unit * 0.04, center.dy + unit * 0.13)
      ..lineTo(center.dx + unit * 0.00, center.dy + unit * 0.23);
    canvas.drawPath(crack, crackPaint);

    _paintEyes(canvas, center.translate(0, -unit * 0.02), unit, 0.055);
  }

  void _paintPetBody(Canvas canvas, Offset center, double unit) {
    final bodyRect = Rect.fromCenter(
      center: center.translate(0, unit * 0.06),
      width: unit * 0.50,
      height: unit * 0.58,
    );
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(const Color(0xFF9FEBC0), AppColors.primaryLight, 0.30)!,
          AppColors.primary,
        ],
      ).createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(unit * 0.22)),
      bodyPaint,
    );

    final bellyPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, unit * 0.15),
        width: unit * 0.30,
        height: unit * 0.24,
      ),
      bellyPaint,
    );

    final leafPaint = Paint()..color = AppColors.primaryLight;
    final leaf = Path()
      ..moveTo(center.dx, center.dy - unit * 0.30)
      ..quadraticBezierTo(
        center.dx + unit * 0.21,
        center.dy - unit * 0.46,
        center.dx + unit * 0.30,
        center.dy - unit * 0.24,
      )
      ..quadraticBezierTo(
        center.dx + unit * 0.12,
        center.dy - unit * 0.25,
        center.dx,
        center.dy - unit * 0.30,
      )
      ..close();
    canvas.drawPath(leaf, leafPaint);

    _paintEyes(canvas, center.translate(0, -unit * 0.06), unit, 0.065);

    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, unit * 0.04),
        width: unit * 0.16,
        height: unit * 0.12,
      ),
      0.16,
      math.pi - 0.32,
      false,
      smilePaint,
    );
  }

  void _paintEyes(Canvas canvas, Offset center, double unit, double radius) {
    final eyePaint = Paint()..color = AppColors.primaryDark;
    final shinePaint = Paint()..color = Colors.white;
    for (final dx in [-unit * 0.10, unit * 0.10]) {
      final eyeCenter = center.translate(dx, 0);
      canvas.drawCircle(eyeCenter, unit * radius, eyePaint);
      canvas.drawCircle(
        eyeCenter.translate(-unit * 0.018, -unit * 0.018),
        unit * radius * 0.34,
        shinePaint,
      );
    }
  }

  void _paintLegs(Canvas canvas, Offset center, double unit) {
    final legPaint = Paint()..color = AppColors.primaryDark;
    for (final dx in [-unit * 0.10, unit * 0.10]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(dx, unit * 0.38),
            width: unit * 0.09,
            height: unit * 0.12,
          ),
          Radius.circular(unit * 0.04),
        ),
        legPaint,
      );
    }
  }

  void _paintBoots(Canvas canvas, Offset center, double unit) {
    final bootPaint = Paint()..color = AppColors.warning;
    for (final dx in [-unit * 0.10, unit * 0.10]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(dx, unit * 0.43),
            width: unit * 0.14,
            height: unit * 0.06,
          ),
          Radius.circular(unit * 0.03),
        ),
        bootPaint,
      );
    }
  }

  void _paintMysticHalo(Canvas canvas, Offset center, double unit) {
    final haloPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.020;
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -unit * 0.34),
        width: unit * 0.36,
        height: unit * 0.09,
      ),
      haloPaint,
    );

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    for (final angle in [0.0, 2.1, 4.2]) {
      canvas.drawCircle(
        center.translate(
          math.cos(angle) * unit * 0.34,
          math.sin(angle) * unit * 0.34,
        ),
        unit * 0.018,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FinancePetAvatarPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.progress != progress ||
        oldDelegate.showEnvironment != showEnvironment;
  }
}
