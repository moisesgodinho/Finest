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
    final colors = context.colors;
    final gradientStart = _shiftColor(colors.primary, lightnessDelta: 0.12);
    final gradientEnd = _shiftColor(colors.primaryDark, lightnessDelta: -0.03);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = (width / 2.25).clamp(156.0, 176.0).toDouble();

        return SizedBox(
          width: double.infinity,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradientStart, gradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primaryDark
                      .withValues(alpha: colors.isDark ? 0.36 : 0.22),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned(
                    left: -86,
                    bottom: -102,
                    child: _BalanceGlow(size: 250, opacity: 0.12),
                  ),
                  Positioned(
                    right: -96,
                    top: -104,
                    child: _BalanceGlow(size: 236, opacity: 0.10),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _BalanceIconButton(
                              isVisible: isVisible,
                              onPressed: onToggleVisibility,
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isVisible ? value : r'R$ ------',
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          _BalanceSubtitlePill(text: subtitle!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceIconButton extends StatelessWidget {
  const _BalanceIconButton({
    required this.isVisible,
    this.onPressed,
  });

  final bool isVisible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final icon =
        isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded;

    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x33FFFFFF)),
          ),
        ),
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _BalanceSubtitlePill extends StatelessWidget {
  const _BalanceSubtitlePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _BalanceGlow extends StatelessWidget {
  const _BalanceGlow({
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: opacity),
      ),
    );
  }
}

Color _shiftColor(Color color, {required double lightnessDelta}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
      .toColor();
}
