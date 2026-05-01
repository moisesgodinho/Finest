import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/result.dart';
import 'backup_service.dart';

class DriveBackupService implements BackupService {
  @override
  Future<Result<File>> createLocalBackup({required int userId}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupsDir = Directory(p.join(directory.path, 'backups'));
      if (!backupsDir.existsSync()) {
        backupsDir.createSync(recursive: true);
      }

      final fileName =
          'finance_pet_user_${userId}_${DateTime.now().millisecondsSinceEpoch}.backup';
      final backupFile = File(p.join(backupsDir.path, fileName));

      // TODO: Copiar o arquivo SQLite real e metadados quando o schema estiver em producao.
      await backupFile.writeAsString('FinancePet local backup placeholder');

      return Result.success(backupFile);
    } catch (error, stackTrace) {
      return Result.failure(error, stackTrace);
    }
  }

  @override
  Future<Result<void>> restoreLocalBackup({
    required int userId,
    required File backupFile,
  }) async {
    try {
      // TODO: Validar versao do schema e restaurar o arquivo SQLite com seguranca.
      if (!backupFile.existsSync()) {
        throw FileSystemException('Backup local nao encontrado.', backupFile.path);
      }
      return Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(error, stackTrace);
    }
  }

  @override
  Future<Result<String>> uploadBackupToDrive({
    required int userId,
    required File backupFile,
  }) async {
    try {
      // TODO: Integrar Google Sign-In e Google Drive API para enviar o backup.
      if (!backupFile.existsSync()) {
        throw FileSystemException('Backup local nao encontrado.', backupFile.path);
      }
      return Result.success('mock-drive-file-id');
    } catch (error, stackTrace) {
      return Result.failure(error, stackTrace);
    }
  }

  @override
  Future<Result<File>> downloadBackupFromDrive({
    required int userId,
    required String driveFileId,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, 'backups', '$driveFileId.backup'));

      // TODO: Baixar o arquivo real do Google Drive e salvar localmente.
      await file.create(recursive: true);
      await file.writeAsString('Downloaded FinancePet backup placeholder');

      return Result.success(file);
    } catch (error, stackTrace) {
      return Result.failure(error, stackTrace);
    }
  }

  @override
  Future<Result<void>> scheduleAutomaticBackup({required int userId}) async {
    try {
      // TODO: Agendar backup automatico com WorkManager no Android e BGTaskScheduler no iOS.
      return Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(error, stackTrace);
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return DriveBackupService();
});
