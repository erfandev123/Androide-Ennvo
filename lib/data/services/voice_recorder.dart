// ============================================================================
//  ENNVO — VOICE RECORDER
//
//  The voice notes of the comment composer.
//
//  The recorder writes an AAC file into the cache of the app and hands the
//  path over to the upload service, which puts it in the bucket.
//
//  Every failure is quiet: a phone that has no microphone, or a user that
//  says no to the permission, simply gets a composer that does not record.
//
//  The device is only created when a note is actually taken: the plugin
//  talks to the native side, and a screen that is never used must not wake
//  it up.
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder;

  AudioRecorder? _recorder;
  bool _disposed = false;

  bool _recording = false;
  String? _path;

  /// Whether a note is being recorded right now.
  bool get isRecording => _recording;

  /// The file the note is written to.
  String? get path => _path;

  /// The recorder of the platform.
  ///
  /// It is created the first time it is needed.
  AudioRecorder? get _device {
    if (_disposed) return null;
    return _recorder ??= AudioRecorder();
  }

  /// Asks for the microphone, if the app does not have it yet.
  Future<bool> ensurePermission() async {
    final device = _device;
    if (device == null) return false;
    try {
      // The `request` flag asks the system for the permission when it is
      // missing.
      return await device.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts a note.
  ///
  /// It returns false when the microphone is not available.
  Future<bool> start() async {
    if (kIsWeb) return false;
    if (_recording) return true;

    final device = _device;
    if (device == null) return false;
    if (!await ensurePermission()) return false;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${Directory.systemTemp.path}/ennvo_voice_$stamp.m4a');

    try {
      await device.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: file.path,
      );
      _path = file.path;
      _recording = true;
      return true;
    } catch (_) {
      _path = null;
      _recording = false;
      return false;
    }
  }

  /// Stops the note and returns the path of the file.
  Future<String?> stop() async {
    final device = _recorder;
    if (!_recording || device == null) return null;
    try {
      await device.stop();
    } catch (_) {
      // The file may still be there.
    }
    _recording = false;
    final path = _path;
    _path = null;
    return path;
  }

  /// Throws the note away.
  Future<void> cancel() async {
    final device = _recorder;
    if (!_recording || device == null) return;
    try {
      await device.cancel();
    } catch (_) {
      // Nothing to do.
    }
    _recording = false;
    _path = null;
  }

  /// The loudness of the microphone.
  ///
  /// It is what the row of the composer wiggles with while a note is being
  /// recorded.
  Future<double> amplitude() async {
    final device = _recorder;
    if (device == null) return 0;
    try {
      return (await device.getAmplitude()).current;
    } catch (_) {
      return 0;
    }
  }

  /// Removes the file of a note that was not sent.
  static Future<void> remove(String? path) async {
    if (kIsWeb || path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The cache is cleaned by the system anyway.
    }
  }

  void dispose() {
    _disposed = true;
    final device = _recorder;
    _recorder = null;
    if (device != null) unawaited(device.dispose());
  }
}
