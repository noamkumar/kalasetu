import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Audio recording service using record package (16 kHz mono WAV)
/// Section 8 of Project Specification
class AudioRecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecordingState = false;
  String? _activeFilePath;

  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking record permission: $e');
      return false;
    }
  }

  Future<String?> startRecording() async {
    if (_isRecordingState) {
      debugPrint('[AudioRecordingService] Recording is already active. Ignoring start request.');
      return _activeFilePath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/craft_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );
      _isRecordingState = true;
      _activeFilePath = filePath;
      return filePath;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      _isRecordingState = false;
      _activeFilePath = null;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecordingState) {
      debugPrint('[AudioRecordingService] Not currently recording.');
      return null;
    }

    try {
      final path = await _audioRecorder.stop();
      _isRecordingState = false;
      final savedPath = path ?? _activeFilePath;
      _activeFilePath = null;

      if (savedPath != null) {
        final file = File(savedPath);
        if (await file.exists()) {
          final length = await file.length();
          // WAV header is ~44 bytes. Require at least 400 bytes to be non-empty speech
          if (length < 400) {
            debugPrint('[AudioRecordingService] Recorded audio is too short ($length bytes). Discarding.');
            await deleteAudioFile(savedPath);
            return null;
          }
          return savedPath;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecordingState = false;
      _activeFilePath = null;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_isRecordingState) {
        final path = await _audioRecorder.stop();
        _isRecordingState = false;
        final targetPath = path ?? _activeFilePath;
        _activeFilePath = null;
        if (targetPath != null) {
          await deleteAudioFile(targetPath);
        }
      }
    } catch (e) {
      debugPrint('Error cancelling audio recording: $e');
      _isRecordingState = false;
      _activeFilePath = null;
    }
  }

  Future<bool> isRecording() async {
    try {
      final active = await _audioRecorder.isRecording();
      return active || _isRecordingState;
    } catch (_) {
      return _isRecordingState;
    }
  }

  Future<void> dispose() async {
    try {
      if (_isRecordingState) {
        await cancelRecording();
      }
      await _audioRecorder.dispose();
    } catch (_) {}
  }

  static Future<void> deleteAudioFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting temp audio file: $e');
    }
  }
}
