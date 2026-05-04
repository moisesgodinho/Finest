import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/demo/demo_data_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/section_card.dart';
import 'settings_view_model.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final user = ref.watch(authStateProvider).user;
    final themePreference = ref.watch(themeControllerProvider);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mais',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Conta e preferências',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ProfileCard(
              name: user?.name ?? 'Camila Souza',
              email: user?.email ?? 'camila@email.com',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SettingsShortcut(
                  icon: Icons.folder_copy_outlined,
                  title: 'Categorias',
                  subtitle: 'Receitas e despesas',
                  onTap: () => context.push(AppRoutes.categories),
                ),
                _SettingsShortcut(
                  icon: Icons.flag_outlined,
                  title: 'Metas',
                  subtitle: 'Objetivos e reservas',
                  onTap: () => context.push(AppRoutes.goals),
                ),
                const _SettingsShortcut(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Contas e cartões',
                  subtitle: 'Vinculados',
                ),
                const _SettingsShortcut(
                  icon: Icons.bar_chart_rounded,
                  title: 'Relatórios',
                  subtitle: 'Resumo mensal',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Preferências',
              child: Column(
                children: [
                  _SwitchSettingTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notificações',
                    subtitle: 'Lembretes, alertas e vencimentos',
                    value: settings.notificationsEnabled,
                    onChanged: viewModel.toggleNotifications,
                  ),
                  _SwitchSettingTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacidade',
                    subtitle: 'Ocultar valores na tela',
                    value: settings.hideValues,
                    onChanged: viewModel.toggleHideValues,
                  ),
                  _SettingTile(
                    icon: Icons.sell_outlined,
                    title: 'Categorias personalizadas',
                    subtitle: 'Editar categorias do app',
                    onTap: () => context.push(AppRoutes.categories),
                  ),
                  _SettingTile(
                    icon: Icons.palette_outlined,
                    title: 'Tema',
                    subtitle: themePreference.label,
                    onTap: () {
                      _showThemePicker(context, ref, themePreference);
                    },
                  ),
                  const _SettingTile(
                    icon: Icons.attach_money_rounded,
                    title: 'Moeda',
                    subtitle: r'Real brasileiro (R$)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Conta',
              child: const Column(
                children: [
                  _SettingTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Assinatura',
                    subtitle: 'Recursos premium futuramente',
                  ),
                  _SettingTile(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Backup Google Drive',
                    subtitle: 'Manual e automático futuramente',
                  ),
                  _SettingTile(
                    icon: Icons.file_download_outlined,
                    title: 'Exportar dados',
                    subtitle: 'CSV e PDF',
                  ),
                  _SettingTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Segurança',
                    subtitle: 'Senha, biometria e acesso',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (kDebugMode) ...[
              SectionCard(
                title: 'Desenvolvimento',
                child: _SettingTile(
                  icon: Icons.restart_alt_rounded,
                  title: 'Recriar dados mockados',
                  subtitle: 'Limpa o SQLite e cria histórico demo',
                  onTap: () => _confirmResetDemoData(context, ref),
                ),
              ),
              const SizedBox(height: 18),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(authStateProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetDemoData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recriar dados mockados?'),
          content: const Text(
            'Isso vai apagar todos os dados locais deste app e criar uma base demo com histórico dos últimos meses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Recriar'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Recriando dados mockados...')),
    );

    try {
      await ref.read(demoDataServiceProvider).resetAndSeedDemoData();
      await ref.read(authStateProvider.notifier).restoreSession();
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Dados mockados recriados.')),
      );
      context.go(AppRoutes.home);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao recriar dados: $error')),
      );
    }
  }

  Future<void> _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppThemePreference currentPreference,
  ) async {
    final colors = context.colors;
    final selectedPreference = await showModalBottomSheet<AppThemePreference>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _ThemePickerSheet(currentPreference: currentPreference);
      },
    );

    if (selectedPreference != null) {
      await ref
          .read(themeControllerProvider.notifier)
          .setPreference(selectedPreference);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: colors.surface,
            foregroundColor: colors.textSecondary,
            child: const Icon(Icons.person_rounded, size: 42),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryLight.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Text(
                      'Plano grátis',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsShortcut extends StatelessWidget {
  const _SettingsShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: _shortcutWidth(context),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  colors.shadow.withValues(alpha: colors.isDark ? 0.32 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.accentSoft,
              foregroundColor: colors.primary,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _shortcutWidth(BuildContext context) {
    const pageHorizontalPadding = 40.0;
    const spacing = 12.0;
    final availableWidth =
        MediaQuery.sizeOf(context).width - pageHorizontalPadding;
    final columnCount = availableWidth >= 720 ? 4 : 2;
    return (availableWidth - spacing * (columnCount - 1)) / columnCount;
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _SettingTileShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        activeThumbColor: colors.primary,
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _SettingTileShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.textSecondary,
      ),
    );
  }
}

class _SettingTileShell extends StatelessWidget {
  const _SettingTileShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.accentSoft,
              foregroundColor: colors.primary,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({
    required this.currentPreference,
  });

  final AppThemePreference currentPreference;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Escolha como o Finest deve aparecer neste aparelho.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          for (final preference in AppThemePreference.values)
            _ThemeOptionTile(
              preference: preference,
              isSelected: preference == currentPreference,
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.preference,
    required this.isSelected,
  });

  final AppThemePreference preference;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(preference),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentSoft : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isSelected ? colors.primary : colors.accentSoft,
                foregroundColor: isSelected ? colors.onPrimary : colors.primary,
                child: Icon(preference.icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preference.label,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preference.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
