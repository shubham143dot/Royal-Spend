import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages reliable, account-isolated local disk persistence for receipt images.
/// Ensures receipt photos survive app restarts, temp file cleans, and offline states.
class ReceiptStorageService {
  ReceiptStorageService._();
  static final ReceiptStorageService instance = ReceiptStorageService._();

  /// Gets the directory dedicated to persistent receipt storage for [userId].
  Future<Directory> _getReceiptDirectory(String? userId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final userSegment = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : 'offline_user';
    final receiptDir = Directory(p.join(appDir.path, 'receipts', userSegment));
    if (!await receiptDir.exists()) {
      await receiptDir.create(recursive: true);
    }
    return receiptDir;
  }

  /// Copies a temporary or camera receipt image from [sourcePath] into permanent
  /// local storage associated with [expenseId] and [userId].
  Future<String?> saveReceiptPermanently({
    required String sourcePath,
    required String expenseId,
    String? userId,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    try {
      final receiptDir = await _getReceiptDirectory(userId);
      final ext = p.extension(sourcePath).toLowerCase();
      final validExt = ext.isNotEmpty ? ext : '.jpg';
      final permanentPath = p.join(receiptDir.path, '$expenseId$validExt');

      // Copy file to permanent storage
      final permanentFile = await sourceFile.copy(permanentPath);
      return permanentFile.path;
    } catch (e) {
      debugPrint('[ReceiptStorageService] Error saving permanent receipt: $e');
      return null;
    }
  }

  /// Deletes a permanently stored receipt file.
  Future<void> deleteReceipt(String? receiptPath) async {
    if (receiptPath == null || receiptPath.isEmpty) return;
    try {
      final file = File(receiptPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[ReceiptStorageService] Error deleting receipt file: $e');
    }
  }

  /// Checks if a local receipt file exists on disk.
  Future<bool> receiptExists(String? receiptPath) async {
    if (receiptPath == null || receiptPath.isEmpty) return false;
    return await File(receiptPath).exists();
  }
}
