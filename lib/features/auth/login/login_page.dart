import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'login_view_model.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginViewModelProvider);
    final viewModel = ref.read(loginViewModelProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          const _LoginHeader(),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    220,
                    22,
                    28 + bottomPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 248 - bottomPadding,
                    ),
                    child: _LoginCard(
                      state: state,
                      onEmailChanged: viewModel.emailChanged,
                      onPasswordChanged: viewModel.passwordChanged,
                      onTogglePassword: viewModel.togglePasswordVisibility,
                      onSubmit: viewModel.submit,
                      onSocialLogin: viewModel.submitSocial,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 360,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryDark,
            colors.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LoginWavePainter()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 38, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Bem-vindo',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Entre para acessar suas finanças',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 86),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.state,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onSocialLogin,
  });

  final LoginFormState state;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;
  final Future<void> Function(SocialAuthProvider provider) onSocialLogin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.44 : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Email',
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              onChanged: onEmailChanged,
            ),
            const SizedBox(height: 22),
            AppTextField(
              label: 'Senha',
              hintText: 'Senha',
              obscureText: !state.isPasswordVisible,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  state.isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
              onChanged: onPasswordChanged,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Esqueci minha senha'),
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Entrar',
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : onSubmit,
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.danger,
                    ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'ou continue com',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 22),
            _SocialButton(
              label: 'Continuar com Google',
              icon: const FaIcon(
                FontAwesomeIcons.google,
                color: Color(0xFF4285F4),
              ),
              onPressed: () => onSocialLogin(SocialAuthProvider.google),
            ),
            const SizedBox(height: 12),
            _SocialButton(
              label: 'Continuar com Apple',
              icon: FaIcon(
                FontAwesomeIcons.apple,
                color: colors.textPrimary,
              ),
              onPressed: () => onSocialLogin(SocialAuthProvider.apple),
            ),
            const SizedBox(height: 12),
            _SocialButton(
              label: 'Continuar com Facebook',
              icon: const FaIcon(
                FontAwesomeIcons.facebookF,
                color: Color(0xFF1877F2),
              ),
              onPressed: () => onSocialLogin(SocialAuthProvider.facebook),
            ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () {},
              child: const Text.rich(
                TextSpan(
                  text: 'Não tem conta? ',
                  children: [
                    TextSpan(
                      text: 'Criar conta',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 34, child: Center(child: icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 46),
          ],
        ),
      ),
    );
  }
}

class _LoginWavePainter extends CustomPainter {
  const _LoginWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);

    for (var i = 0; i < 18; i++) {
      final path = Path();
      final y = size.height * 0.48 + i * 8;
      path.moveTo(size.width * 0.15, y);
      path.cubicTo(
        size.width * 0.45,
        y - 78,
        size.width * 0.72,
        y + 72,
        size.width * 1.12,
        y - 52,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
