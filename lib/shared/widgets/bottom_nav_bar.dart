import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FinestBottomNavBar extends StatelessWidget {
  const FinestBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _FinestNavItem(
      icon: Icons.home_outlined,
      label: 'Início',
    ),
    _FinestNavItem(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Contas',
    ),
    _FinestNavItem(
      icon: Icons.pie_chart_outline_rounded,
      label: 'Planejamento',
    ),
    _FinestNavItem(
      icon: Icons.credit_card_outlined,
      label: 'Cartões',
    ),
    _FinestNavItem(
      icon: Icons.more_horiz_rounded,
      label: 'Mais',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final navColor = colors.isDark ? colors.surfaceElevated : colors.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: navColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colors.border.withValues(alpha: colors.isDark ? 0.72 : 0.48),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.45 : 0.1),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _FinestNavButton(
                    item: _items[index],
                    isSelected: index == currentIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinestNavButton extends StatelessWidget {
  const _FinestNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _FinestNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = colors.primaryLight;
    final inactiveColor = colors.isDark
        ? colors.textSecondary
        : AppColors.textPrimary.withValues(alpha: 0.9);

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        containedInkWell: false,
        child: SizedBox(
          height: 76,
          child: isSelected
              ? _SelectedNavIcon(
                  icon: item.icon,
                  backgroundColor: activeColor,
                  iconColor: colors.onPrimary,
                )
              : _InactiveNavItem(
                  icon: item.icon,
                  label: item.label,
                  color: inactiveColor,
                ),
        ),
      ),
    );
  }
}

class _SelectedNavIcon extends StatelessWidget {
  const _SelectedNavIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 26,
        ),
      ),
    );
  }
}

class _InactiveNavItem extends StatelessWidget {
  const _InactiveNavItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 4),
            SizedBox(
              width: 76,
              height: 16,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinestNavItem {
  const _FinestNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
