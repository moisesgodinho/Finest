import 'package:drift/drift.dart';

import 'users_table.dart';

class BackupLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get backupType => text().withLength(min: 1, max: 40)();
  TextColumn get provider => text().withLength(min: 1, max: 40)();
  TextColumn get status => text().withLength(min: 1, max: 40)();
  TextColumn get filePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
