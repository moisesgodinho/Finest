import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FormOption<T> {
  const FormOption({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? description;
}

class FormOptionSelector<T> extends StatelessWidget {
  const FormOptionSelector({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String title;
  final T value;
  final List<FormOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              _FormOptionPill<T>(
                option: option,
                isSelected: option.value == value,
                onTap: () => onChanged(option.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _FormOptionPill<T> extends StatelessWidget {
  const _FormOptionPill({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final FormOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedBackground =
        colors.isDark ? colors.primaryLight : colors.primary;
    final selectedForeground =
        colors.isDark ? AppColors.textPrimary : colors.onPrimary;
    final unselectedBackground =
        colors.isDark ? colors.surfaceElevated : colors.surface;
    final unselectedIconBackground = colors.accentSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : unselectedBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(
                        alpha: colors.isDark ? 0.22 : 0.14,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : unselectedIconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: isSelected ? selectedForeground : colors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          isSelected ? selectedForeground : colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
