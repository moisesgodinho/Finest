import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/app_user.dart';

abstract class UserRepository {
  Future<AppUser?> findById(int id);

  Future<AppUser?> findByEmail(String email);

  Future<AppUser> findOrCreate({
    required String name,
    required String email,
  });
}

class DriftUserRepository implements UserRepository {
  const DriftUserRepository(this._database);

  final AppDatabase _database;

  @override
  Future<AppUser?> findById(int id) async {
    final user = await _database.usersDao.findById(id);
    return user == null ? null : _mapUser(user);
  }

  @override
  Future<AppUser?> findByEmail(String email) async {
    final user = await _database.usersDao.findByEmail(email.trim());
    return user == null ? null : _mapUser(user);
  }

  @override
  Future<AppUser> findOrCreate({
    required String name,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final existingUser = await _database.usersDao.findByEmail(normalizedEmail);
    if (existingUser != null) {
      return _mapUser(existingUser);
    }

    final now = DateTime.now();
    final userId = await _database.usersDao.insertUser(
      UsersCompanion.insert(
        name: name.trim(),
        email: normalizedEmail,
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final user = await _database.usersDao.findById(userId);
    return _mapUser(user!);
  }

  AppUser _mapUser(User user) {
    return AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
    );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return DriftUserRepository(ref.watch(appDatabaseProvider));
});
