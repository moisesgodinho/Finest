import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/user_repository.dart';

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

class LocalAuthService implements AuthService {
  const LocalAuthService({
    required UserRepository userRepository,
    required CategoryRepository categoryRepository,
  })  : _userRepository = userRepository,
        _categoryRepository = categoryRepository;

  static const sessionUserIdKey = 'finest.session_user_id';

  final UserRepository _userRepository;
  final CategoryRepository _categoryRepository;

  @override
  Future<AppUser?> currentUser() async {
    final preferences = await SharedPreferences.getInstance();
    final userId = preferences.getInt(sessionUserIdKey);
    if (userId == null) {
      return null;
    }

    final user = await _userRepository.findById(userId);
    if (user == null) {
      await preferences.remove(sessionUserIdKey);
    } else {
      await _categoryRepository.ensureDefaultCategories(user.id);
    }
    return user;
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.trim().isEmpty) {
      throw AuthException('Informe email e senha para continuar.');
    }

    final user = await _userRepository.findOrCreate(
      name: _nameFromEmail(normalizedEmail),
      email: normalizedEmail,
    );
    await _categoryRepository.ensureDefaultCategories(user.id);
    await _saveSession(user.id);
    return user;
  }

  @override
  Future<AppUser> signInWithProvider(SocialAuthProvider provider) async {
    final user = await _userRepository.findOrCreate(
      name: _providerDisplayName(provider),
      email: '${provider.name}@finest.local',
    );
    await _categoryRepository.ensureDefaultCategories(user.id);
    await _saveSession(user.id);
    return user;
  }

  @override
  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(sessionUserIdKey);
  }

  Future<void> _saveSession(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(sessionUserIdKey, userId);
  }

  String _nameFromEmail(String email) {
    final namePart = email.split('@').first.replaceAll('.', ' ').trim();
    if (namePart.isEmpty) {
      return 'Usuário Finest';
    }

    return namePart
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _providerDisplayName(SocialAuthProvider provider) {
    return switch (provider) {
      SocialAuthProvider.google => 'Usuário Google',
      SocialAuthProvider.apple => 'Usuário Apple',
      SocialAuthProvider.facebook => 'Usuário Facebook',
    };
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
  AuthController(this._authService) : super(const AuthState(isLoading: true)) {
    restoreSession();
  }

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
  return LocalAuthService(
    userRepository: ref.watch(userRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
  );
});

final authStateProvider = StateNotifierProvider<AuthController, AuthState>((
  ref,
) {
  return AuthController(ref.watch(authServiceProvider));
});
