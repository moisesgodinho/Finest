import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<User?> findById(int id) {
    return (select(users)..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<User?> findByEmail(String email) {
    return (select(users)..where((table) => table.email.equals(email)))
        .getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion user) {
    return into(users).insert(user);
  }
}
