import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.icon = const Icon(Icons.more_vert_rounded),
    this.iconColor,
    this.padding = const EdgeInsets.all(8),
    this.enabled = true,
    this.reservedBottomHeight,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T>? onSelected;
  final VoidCallback? onCanceled;
  final String? tooltip;
  final Widget icon;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  /// Optional space kept clear at the bottom of the screen.
  ///
  /// When omitted, the button reserves only the app bottom navigation height
  /// when it is inside a Scaffold that has one.
  final double? reservedBottomHeight;

  static const _screenGap = 8.0;
  static const _buttonGap = 3.0;
  static const _defaultMenuConstraints = BoxConstraints(
    minWidth: 112,
    maxWidth: 280,
  );

  @override
  Widget build(BuildContext context) {
    final popupTheme = PopupMenuTheme.of(context);
    final resolvedIconColor =
        iconColor ?? popupTheme.iconColor ?? IconTheme.of(context).color;

    return IconButton(
      tooltip: tooltip ?? 'Opções',
      onPressed: enabled ? () => _showMenu(context) : null,
      padding: padding,
      color: resolvedIconColor,
      iconSize: popupTheme.iconSize,
      icon: icon,
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final items = itemBuilder(context);
    if (items.isEmpty) {
      return;
    }

    final button = context.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (button is! RenderBox || overlay is! RenderBox) {
      return;
    }

    final positionData = _positionData(context, button, overlay, items);
    final selected = await showMenu<T>(
      context: context,
      position: positionData.position,
      items: items,
      constraints: _defaultMenuConstraints.copyWith(
        maxHeight: positionData.maxHeight,
      ),
    );

    if (selected == null) {
      onCanceled?.call();
      return;
    }
    onSelected?.call(selected);
  }

  _PopupPositionData _positionData(
    BuildContext context,
    RenderBox button,
    RenderBox overlay,
    List<PopupMenuEntry<T>> items,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final popupTheme = PopupMenuTheme.of(context);
    final textDirection = Directionality.of(context);
    final iconSize = popupTheme.iconSize ?? IconTheme.of(context).size ?? 24;
    final menuPadding =
        popupTheme.menuPadding ?? const EdgeInsets.symmetric(vertical: 8);
    final verticalPadding = menuPadding.resolve(textDirection).vertical;

    final estimatedMenuHeight = items.fold<double>(
      verticalPadding,
      (sum, item) => sum + item.height,
    );
    final overlaySize = overlay.size;
    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero),
          ancestor: overlay),
    );

    final reservedTop = mediaQuery.padding.top + _screenGap;
    final hasBottomNavigation = context
            .findAncestorWidgetOfExactType<Scaffold>()
            ?.bottomNavigationBar !=
        null;
    final bottomReservedHeight =
        reservedBottomHeight ?? (hasBottomNavigation ? 76.0 : 0.0);
    final reservedBottom = mediaQuery.padding.bottom + bottomReservedHeight;
    final usableHeight =
        overlaySize.height - reservedTop - reservedBottom - _screenGap;
    final maxMenuHeight = usableHeight > 96 ? usableHeight : 96.0;
    final effectiveMenuHeight = estimatedMenuHeight > maxMenuHeight
        ? maxMenuHeight
        : estimatedMenuHeight;
    final iconTop = buttonRect.center.dy - iconSize / 2;
    final iconLeft = buttonRect.center.dx - iconSize / 2;
    final targetTop = iconTop;
    final maxTop =
        overlaySize.height - reservedBottom - effectiveMenuHeight - _screenGap;
    final boundedTop = maxTop <= reservedTop
        ? reservedTop
        : targetTop.clamp(reservedTop, maxTop).toDouble();
    final anchorRight = iconLeft - _buttonGap;
    final anchorRect = Rect.fromLTWH(
      anchorRight,
      boundedTop,
      0,
      buttonRect.height,
    );

    return _PopupPositionData(
      position: RelativeRect.fromRect(anchorRect, Offset.zero & overlaySize),
      maxHeight: maxMenuHeight,
    );
  }
}

class _PopupPositionData {
  const _PopupPositionData({
    required this.position,
    required this.maxHeight,
  });

  final RelativeRect position;
  final double maxHeight;
}

class AppPopupMenuItem extends StatelessWidget {
  const AppPopupMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = isDestructive ? colors.danger : colors.primary;
    final backgroundColor = isDestructive
        ? colors.danger.withValues(alpha: colors.isDark ? 0.16 : 0.10)
        : colors.accentSoft;

    return SizedBox(
      width: 184,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDestructive ? colors.danger : colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
