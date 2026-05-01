import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.isVisible = true,
    this.onToggleVisibility,
    super.key,
  });

  final String title;
  final String value;
  final String? subtitle;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 186),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _FinanceWavePainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (onToggleVisibility != null)
                      IconButton.filledTonal(
                        onPressed: onToggleVisibility,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.38),
                        ),
                        icon: Icon(
                          isVisible
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isVisible ? value : r'R$ ------',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 40,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.16);

    for (var i = 0; i < 12; i++) {
      final path = Path();
      final verticalOffset = size.height * 0.55 + i * 7;
      path.moveTo(size.width * 0.20, verticalOffset);
      path.cubicTo(
        size.width * 0.48,
        verticalOffset - 80,
        size.width * 0.72,
        verticalOffset + 60,
        size.width * 1.08,
        verticalOffset - 34,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
