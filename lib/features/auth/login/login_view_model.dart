import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';

class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool isSubmitting;
  final String? errorMessage;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LoginViewModel extends StateNotifier<LoginFormState> {
  LoginViewModel(this._ref) : super(const LoginFormState());

  final Ref _ref;

  void emailChanged(String value) {
    state = state.copyWith(email: value, clearError: true);
  }

  void passwordChanged(String value) {
    state = state.copyWith(password: value, clearError: true);
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(authStateProvider.notifier).signInWithEmailAndPassword(
            email: state.email,
            password: state.password,
          );
      state = state.copyWith(isSubmitting: false);
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> submitSocial(SocialAuthProvider provider) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(authStateProvider.notifier).signInWithProvider(provider);
      state = state.copyWith(isSubmitting: false);
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }
}

final loginViewModelProvider =
    StateNotifierProvider.autoDispose<LoginViewModel, LoginFormState>((ref) {
  return LoginViewModel(ref);
});
