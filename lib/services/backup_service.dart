import 'package:insurance_manager/utils/app_logger.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive_io.dart';
import 'package:insurance_manager/database/database_helper.dart';

/// 备份服务 - 提供自动定时本地备份、完整备份、数据恢复功能
class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  // Keys for SharedPreferences
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyBackupIntervalHours = 'backup_interval_hours';
  static const String _keyLastBackupTime = 'last_backup_time';
  static const String _keyMaxBackupsCount = 'max_backups_count';

  // Defaults
  static const int defaultIntervalHours = 24; // 默认24小时
  static const int defaultMaxBackups = 5; // 默认保留5个备份

  /// Get the backup directory
  Future<Directory> get _backupDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docsDir.path, 'backups'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  // ===== Auto Backup Settings (SharedPreferences) =====

  Future<bool> isAutoBackupEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoBackupEnabled) ?? false;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, enabled);
  }

  Future<int> getBackupIntervalHours() async {
    if (kIsWeb) return defaultIntervalHours;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBackupIntervalHours) ?? defaultIntervalHours;
  }

  Future<void> setBackupIntervalHours(int hours) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBackupIntervalHours, hours);
  }

  Future<int> getMaxBackupsCount() async {
    if (kIsWeb) return defaultMaxBackups;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxBackupsCount) ?? defaultMaxBackups;
  }

  Future<void> setMaxBackupsCount(int count) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxBackupsCount, count);
  }

  Future<DateTime?> getLastBackupTime() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_keyLastBackupTime);
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackupTime, time.toIso8601String());
  }

  // ===== Core Backup Logic =====

  /// Create a full backup (DB + attachments) as a .zip file
  /// Returns the backup file path
  Future<String> createFullBackup({bool isAutoBackup = false}) async {
    if (kIsWeb) throw Exception('Web平台不支持备份');

    final dbHelper = DatabaseHelper.instance;
    final dbPath = await dbHelper.getDatabasePath();
    final dbFile = File(dbPath);

    if (!dbFile.existsSync()) throw Exception('数据库文件不存在');

    // Ensure all data is flushed from WAL to main database file before copying
    final db = await dbHelper.database;
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');

    // Prepare backup archive
    final encoder = ZipFileEncoder();
    final backupDir = await _backupDir;
    final backupTime = DateTime.now();
    final timestamp = backupTime.toString().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final zipPath = path.join(
      backupDir.path,
      '${isAutoBackup ? "auto_" : "manual_"}backup_$timestamp.zip',
    );

    encoder.create(zipPath);

    try {
      // 1. Add database file
      encoder.addFile(dbFile, path.basename(dbPath));

      // 2. Add attachment directories if they exist
      final docsDir = await getApplicationDocumentsDirectory();
      final dirsToBackup = [
        'customer_photos',
        'product_attachments',
        'thumbnails',
      ];

      for (final dirName in dirsToBackup) {
        final dir = Directory(path.join(docsDir.path, dirName));
        if (dir.existsSync()) {
          _addDirectoryToZip(encoder, dir, dirName);
        }
      }

      // 3. Add metadata JSON
      final metadata = {
        'version': '1.0.0',
        'backup_type': isAutoBackup ? 'auto' : 'manual',
        'created_at': backupTime.toIso8601String(),
        'platform': !kIsWeb ? Platform.operatingSystem : 'web',
        'db_version': DatabaseHelper.databaseVersion,
        'files': [
          {'name': 'insurance_manager.db', 'type': 'database'},
          ...dirsToBackup.map((d) => {'name': d, 'type': 'directory'}),
        ],
      };
      final metaJson = jsonEncode(metadata);
      final tempDir = await Directory.systemTemp.createTemp('backup');
      final metaFile = File(path.join(tempDir.path, 'metadata.json'));
      await metaFile.writeAsString(metaJson, flush: true);
      encoder.addFile(metaFile, 'metadata.json');
      await metaFile.delete();
      try { await tempDir.delete(); } catch (_) {}
    } catch (e) {
      encoder.close();
      // Delete incomplete ZIP file on failure
      try { if (File(zipPath).existsSync()) File(zipPath).deleteSync(); } catch (_) {}
      rethrow;
    }

    encoder.close();

    // Update last backup time
    await _saveLastBackupTime(backupTime);

    // Cleanup old backups
    await _cleanupOldBackups();

    return zipPath;
  }

  void _addDirectoryToZip(ZipFileEncoder encoder, Directory dir, String basePath) {
    dir.listSync(recursive: true, followLinks: false).forEach((entity) {
      if (entity is File) {
        try {
          // ZIP spec requires forward slashes for internal paths
          final relativePath = '$basePath/${path.relative(entity.path, from: dir.parent.path)}'.replaceAll('\\', '/');
          encoder.addFile(entity, relativePath);
        } catch (e) {
          AppLogger.warning('Failed to add file to backup: ${entity.path}, error: $e');
        }
      }
    });
  }

  /// Clean up old backups beyond max count
  Future<void> _cleanupOldBackups() async {
    final maxCount = await getMaxBackupsCount();
    final backupDir = await _backupDir;
    final files = backupDir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    while (files.length > maxCount && maxCount > 0) {
      final oldest = files.removeLast();
      try { await oldest.delete(); } catch (_) {}
    }
  }

  /// Restore from a backup .zip file
  Future<(bool success, String message)> restoreFromBackup(String zipPath) async {
    if (kIsWeb) return (false, 'Web平台不支持恢复');

    try {
      final zipFile = File(zipPath);
      if (!zipFile.existsSync()) return (false, '备份文件不存在');

      // Close database BEFORE extracting files to prevent corruption
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.closeDatabase();

      final inputStream = InputFileStream(zipPath);
      try {
      final archive = ZipDecoder().decodeBuffer(inputStream);

      final docsDir = await getApplicationDocumentsDirectory();

      for (final file in archive) {
        if (file.name.isEmpty) continue; // skip empty-named entries
        final filePath = path.join(docsDir.path, file.name);
        // Zip Slip protection: ensure the resolved path is still under docsDir
        final canonicalDocs = path.canonicalize(docsDir.path);
        final canonicalTarget = path.canonicalize(filePath);
        if (!path.isWithin(canonicalDocs, canonicalTarget) && canonicalTarget != canonicalDocs) {
          continue; // skip malicious entries that escape the target directory
        }
        if (file.isFile) {
          final outFile = File(filePath);
          outFile.parent.createSync(recursive: true);
          final outputStream = OutputFileStream(filePath);
          file.writeContent(outputStream);
          outputStream.close();
        } else {
          final canonicalDir = path.canonicalize(filePath);
          if (canonicalDir.startsWith(canonicalDocs)) {
            Directory(filePath).createSync(recursive: true);
          }
        }
      }

      // After extraction, rename old database file if present
      // Only rename if insurance_manager.db does NOT already exist (from the backup)
      final oldDbFile = File(path.join(docsDir.path, 'insurance_app.db'));
      final newDbFile = File(path.join(docsDir.path, 'insurance_manager.db'));
      if (oldDbFile.existsSync() && !newDbFile.existsSync()) {
        try {
          await oldDbFile.rename(newDbFile.path);
        } catch (e) {
          // rename may fail across filesystems, fall back to copy + delete
          try {
            await oldDbFile.copy(newDbFile.path);
            await oldDbFile.delete();
          } catch (e2) {
            AppLogger.error('Failed to migrate old database: $e2');
          }
        }
      }

      // Reopen DB after restore
      await dbHelper.database;

      return (true, '恢复成功！请重启应用以确保所有数据正确加载');
      } finally {
        inputStream.close();
      }
    } catch (e) {
      return (false, '恢复失败：$e');
    }
  }

  /// Check if auto backup should run
  Future<bool> shouldRunAutoBackup() async {
    final enabled = await isAutoBackupEnabled();
    if (!enabled) return false;

    final lastTime = await getLastBackupTime();
    if (lastTime == null) return true;

    final interval = await getBackupIntervalHours();
    final now = DateTime.now();
    return now.difference(lastTime) >= Duration(hours: interval);
  }

  /// Run auto backup if needed (call on app start)
  Future<void> runAutoBackupIfNeeded() async {
    try {
      if (!await shouldRunAutoBackup()) return;
      await createFullBackup(isAutoBackup: true);
    } catch (e) {
      AppLogger.warning(' Auto backup failed: $e');
    }
  }

  /// Get list of all backups with info
  Future<List<BackupInfo>> getBackupList() async {
    if (kIsWeb) return [];

    final backupDir = await _backupDir;
    final files = backupDir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    List<BackupInfo> result = [];
    for (final file in files) {
      final size = file.lengthSync();
      result.add(BackupInfo(
        path: file.path,
        fileName: path.basename(file.path),
        sizeBytes: size,
        sizeFormatted: _formatFileSize(size),
        created: file.lastModifiedSync(),
        isAuto: path.basename(file.path).startsWith('auto_'),
      ));
    }
    return result;
  }

  /// Delete a specific backup
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Export a single backup file for sharing/moving to cloud
  Future<File> exportBackupForSharing(String backupPath) async {
    if (kIsWeb) throw Exception('Web平台不支持导出备份');
    final file = File(backupPath);
    if (!file.existsSync()) throw Exception('备份不存在');

    final shareDir = Directory(path.join(
      (await getApplicationDocumentsDirectory()).path, 'exports', 'backups',
    ));
    shareDir.createSync(recursive: true);

    final targetPath = path.join(shareDir.path, path.basename(backupPath));
    return await file.copy(targetPath);
  }

  /// Import a backup from external location (copy to backup dir)
  Future<String> importBackupFromExternal(File sourceFile) async {
    if (kIsWeb) throw Exception('Web平台不支持导入备份');
    final backupDir = await _backupDir;
    final targetPath = path.join(backupDir.path, path.basename(sourceFile.path));
    // Avoid overwriting existing backup with same name
    if (File(targetPath).existsSync()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = path.extension(sourceFile.path);
      final base = path.basenameWithoutExtension(sourceFile.path);
      return (await sourceFile.copy(path.join(backupDir.path, '${base}_$timestamp$ext'))).path;
    }
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Info about a backup entry
class BackupInfo {
  final String path;
  final String fileName;
  final int sizeBytes;
  final String sizeFormatted;
  final DateTime created;
  final bool isAuto;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.sizeFormatted,
    required this.created,
    required this.isAuto,
  });
}
