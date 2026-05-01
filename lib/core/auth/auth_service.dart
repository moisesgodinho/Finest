import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';

enum SocialAuthProvider {
  google,
  apple,
  facebook,
}

abstract class AuthService {
  Future<AppUser?> currentUser();

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithProvider(SocialAuthProvider provider);

  Future<void> signOut();
}

class MockAuthService implements AuthService {
  AppUser? _currentUser;

  @override
  Future<AppUser?> currentUser() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _currentUser;
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw AuthException('Informe email e senha para continuar.');
    }

    _currentUser = AppUser(
      id: 1,
      name: 'Camila Souza',
      email: email.trim(),
    );
    return _currentUser!;
  }

  @override
  Future<AppUser> signInWithProvider(SocialAuthProvider provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    _currentUser = const AppUser(
      id: 1,
      name: 'Camila Souza',
      email: 'camila@email.com',
    );
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _currentUser = null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(const AuthState());

  final AuthService _authService;

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.currentUser();
      state = AuthState(user: user);
    } catch (error) {
      state = AuthState(errorMessage: error.toString());
    }
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AuthState(user: user);
    } catch (error) {
      state = AuthState(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> signInWithProvider(SocialAuthProvider provider) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signInWithProvider(provider);
      state = AuthState(user: user);
    } catch (error) {
      state = AuthState(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _authService.signOut();
    state = const AuthState();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return MockAuthService();
});

final authStateProvider = StateNotifierProvider<AuthController, AuthState>((
  ref,
) {
  return AuthController(ref.watch(authServiceProvider));
});
