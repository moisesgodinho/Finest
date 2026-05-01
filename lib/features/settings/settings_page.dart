import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/section_card.dart';
import 'settings_view_model.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final user = ref.watch(authStateProvider).user;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mais', style: Theme.of(context).textTheme.headlineMedium),
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
              children: const [
                _SettingsShortcut(
                  icon: Icons.folder_copy_outlined,
                  title: 'Categorias',
                  subtitle: 'Receitas e despesas',
                ),
                _SettingsShortcut(
                  icon: Icons.flag_outlined,
                  title: 'Metas',
                  subtitle: 'Objetivos e reservas',
                ),
                _SettingsShortcut(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Contas e cartões',
                  subtitle: 'Vinculados',
                ),
                _SettingsShortcut(
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
                  const _SettingTile(
                    icon: Icons.sell_outlined,
                    title: 'Categorias personalizadas',
                    subtitle: 'Editar categorias do app',
                  ),
                  const _SettingTile(
                    icon: Icons.palette_outlined,
                    title: 'Tema',
                    subtitle: 'Claro',
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textSecondary,
            child: Icon(Icons.person_rounded, size: 42),
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
                    color: AppColors.primaryLight.withValues(alpha: 0.20),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.primary,
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
    );
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
    return _SettingTileShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        activeThumbColor: AppColors.primary,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SettingTileShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.primary,
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
    );
  }
}
