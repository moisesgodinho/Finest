import 'dart:io';

import '../utils/result.dart';

abstract class BackupService {
  Future<Result<File>> createLocalBackup({required int userId});

  Future<Result<void>> restoreLocalBackup({
    required int userId,
    required File backupFile,
  });

  Future<Result<String>> uploadBackupToDrive({
    required int userId,
    required File backupFile,
  });

  Future<Result<File>> downloadBackupFromDrive({
    required int userId,
    required String driveFileId,
  });

  Future<Result<void>> scheduleAutomaticBackup({required int userId});
}
