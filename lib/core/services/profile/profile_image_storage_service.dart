import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Account-specific offline storage service for profile pictures.
///
/// Every uploaded profile picture is saved locally on the device and strictly
/// keyed by the authenticated user's unique UID.
class ProfileImageStorageService {
  static final ProfileImageStorageService instance = ProfileImageStorageService._internal();

  ProfileImageStorageService._internal();

  /// Visible for testing to inject a custom base directory.
  @visibleForTesting
  ProfileImageStorageService.withDirectory(this._customBaseDir);

  Directory? _customBaseDir;

  /// Max allowable image file size before rejection (10 MB).
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Permitted file extensions.
  static const Set<String> supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  };

  /// Resolves the dedicated local directory for storing profile images.
  Future<Directory> getProfileImagesDirectory() async {
    if (_customBaseDir != null) {
      final dir = Directory(p.join(_customBaseDir!.path, 'profile_images'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final dir = Directory(p.join(Directory.systemTemp.path, 'profile_images'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory(p.join(appDocsDir.path, 'profile_images'));
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }
      return profileDir;
    } catch (e) {
      debugPrint('ProfileImageStorageService: using temp directory fallback: $e');
      final tempDir = await getTemporaryDirectory();
      final profileDir = Directory(p.join(tempDir.path, 'profile_images'));
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }
      return profileDir;
    }
  }

  /// Returns the persistent local profile image file for a given [uid] if it exists and is valid.
  /// If the file is corrupted (e.g. 0 bytes), safely cleans it up and returns null.
  Future<File?> getProfileImageFile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final dir = await getProfileImagesDirectory();
    final file = File(p.join(dir.path, '$uid.jpg'));

    if (await file.exists()) {
      try {
        final length = await file.length();
        if (length > 0) {
          return file;
        } else {
          // 0-byte corrupt file
          await file.delete();
          return null;
        }
      } catch (e) {
        debugPrint('ProfileImageStorageService: failed reading image for $uid: $e');
        return null;
      }
    }
    return null;
  }

  /// Validates, atomically writes, and saves a local profile image for [uid].
  ///
  /// Guarantees that if writing is interrupted or fails, any pre-existing
  /// image is preserved.
  Future<File> saveProfileImage(String uid, File sourceFile) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      throw ArgumentError('Cannot save profile image: user UID is empty.');
    }

    if (!await sourceFile.exists()) {
      throw const FileSystemException('Selected image file does not exist on disk.');
    }

    final ext = p.extension(sourceFile.path).toLowerCase();
    if (ext.isNotEmpty && !supportedExtensions.contains(ext)) {
      throw const FormatException(
        'Unsupported image format. Please select a JPG, PNG, WEBP, or HEIC image.',
      );
    }

    final length = await sourceFile.length();
    if (length == 0) {
      throw const FormatException('Selected image file is empty or corrupted.');
    }
    if (length > maxFileSizeBytes) {
      throw const FormatException('Image file size exceeds the 10 MB limit.');
    }

    final dir = await getProfileImagesDirectory();
    final targetFile = File(p.join(dir.path, '$cleanUid.jpg'));
    final tempFile = File(p.join(dir.path, '${cleanUid}_tmp_${DateTime.now().millisecondsSinceEpoch}.jpg'));

    try {
      // 1. Write to temporary staging file first
      final bytes = await sourceFile.readAsBytes();
      await tempFile.writeAsBytes(bytes, flush: true);

      // Verify written temp file
      if (await tempFile.length() == 0) {
        throw const FileSystemException('Failed to write temporary image file.');
      }

      // 2. Atomically rename/overwrite destination file
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      return targetFile;
    } catch (e) {
      // Clean up temp file on failure
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Deletes the local profile image associated with [uid].
  Future<void> deleteProfileImage(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      final dir = await getProfileImagesDirectory();
      final file = File(p.join(dir.path, '$uid.jpg'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('ProfileImageStorageService: failed deleting image for $uid: $e');
    }
  }

  /// Checks whether a valid local profile image exists for [uid].
  Future<bool> hasProfileImage(String uid) async {
    final file = await getProfileImageFile(uid);
    return file != null;
  }
}
