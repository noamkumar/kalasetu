import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// KalaSetu Audio Cache
///
/// Manages local disk caching for synthesized voice audio.
/// Inbuilt cache versioning ('kalamitra_warm_female_v3') ensures
/// older faster or outdated audio is invalidated.
class AudioCache {
  static const String currentVersion = 'kalamitra_warm_female_v3';
  static final AudioCache _instance = AudioCache._internal();
  factory AudioCache() => _instance;
  AudioCache._internal();

  /// Computes deterministic SHA-256 hash incorporating text, language, voice profile, and voice version
  static String computeHash(
    String text,
    String lang, [
    String voice = currentVersion,
  ]) {
    final key = '${text.trim().toLowerCase()}|${lang.trim().toLowerCase()}|${voice.trim().toLowerCase()}|$currentVersion';
    return sha256.convert(utf8.encode(key)).toString();
  }

  /// Get or create local device voice cache directory
  Future<Directory> getCacheDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${docDir.path}/voice_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Check if a valid WAV file exists in cache for the given hash.
  /// Validates RIFF/WAVE header and purges legacy/corrupt sine waves (32044 bytes).
  Future<File?> getValidCachedFile(String hash) async {
    if (kIsWeb) return null;
    try {
      final cacheDir = await getCacheDirectory();
      final localFile = File('${cacheDir.path}/$hash.wav');
      if (!await localFile.exists()) return null;

      final len = await localFile.length();
      // Purge corrupted or legacy 440Hz sine-wave mock files (32044 bytes)
      if (len == 32044 || len <= 44) {
        debugPrint('[AudioCache] Purging corrupted/mock cache file: ${localFile.path} ($len bytes)');
        await localFile.delete();
        return null;
      }

      // Verify RIFF/WAVE container header
      final headerBytes = await localFile.openRead(0, 12).first;
      final headerStr = String.fromCharCodes(headerBytes);
      if (headerStr.startsWith('RIFF') && headerStr.contains('WAVE')) {
        return localFile;
      } else {
        debugPrint('[AudioCache] Invalid WAV header ($headerStr), purging cache file: ${localFile.path}');
        await localFile.delete();
        return null;
      }
    } catch (e) {
      debugPrint('[AudioCache] Cache check error: $e');
      return null;
    }
  }

  /// Read cached audio bytes if available and valid
  Future<Uint8List?> getCachedBytes(String hash) async {
    final file = await getValidCachedFile(hash);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[AudioCache] Error reading cached file: $e');
      return null;
    }
  }

  /// Save audio bytes to cache file asynchronously
  Future<void> saveAudio(String hash, Uint8List audioBytes) async {
    if (kIsWeb) return;
    // Validate genuine audio before persisting
    if (audioBytes.length <= 44 || audioBytes.length == 32044) {
      debugPrint('[AudioCache] Skipping save for invalid/mock audio (${audioBytes.length} bytes)');
      return;
    }

    final headerStr = String.fromCharCodes(audioBytes.sublist(0, 12));
    if (!headerStr.startsWith('RIFF') || !headerStr.contains('WAVE')) {
      debugPrint('[AudioCache] Skipping save: not a valid RIFF/WAVE stream');
      return;
    }

    try {
      final cacheDir = await getCacheDirectory();
      final localFile = File('${cacheDir.path}/$hash.wav');
      await localFile.writeAsBytes(audioBytes);
      debugPrint('[AudioCache] Cached $hash (${audioBytes.length} bytes) to disk.');
    } catch (e) {
      debugPrint('[AudioCache] Failed to save audio cache: $e');
    }
  }
}
