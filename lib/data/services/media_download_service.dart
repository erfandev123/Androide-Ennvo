// ============================================================================
//  ENNVO — MEDIA DOWNLOADS
//
//  The "Download" button of the share sheet saves the reel to the Downloads
//  folder of the phone.
//
//  The file is handed to Android's own DownloadManager, through the
//  `ennvo/media` channel of the native shell. That keeps the download out of
//  the Flutter isolate — it carries on when the app is in the background,
//  it shows the system notification, and it needs no storage permission on
//  Android 10 and newer.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaDownloadService {
  const MediaDownloadService._();

  static const MethodChannel _channel = MethodChannel('ennvo/media');

  /// Queues [url] for download. Returns as soon as the system accepted it.
  ///
  /// Throws a [MediaDownloadException] when the platform cannot take it.
  static Future<void> download(String url, {String? fileName}) async {
    if (url.isEmpty) {
      throw const MediaDownloadException('There is nothing to download.');
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const MediaDownloadException(
        'Saving a reel is available in the Android app.',
      );
    }

    try {
      await _channel.invokeMethod<void>('download', {
        'url': url,
        'fileName': fileName ?? 'ennvo_${DateTime.now().millisecondsSinceEpoch}.mp4',
      });
    } on PlatformException catch (error) {
      throw MediaDownloadException(
        error.message ?? 'The download could not start.',
      );
    } on MissingPluginException {
      throw const MediaDownloadException(
        'Saving a reel is available in the Android app.',
      );
    }
  }
}

class MediaDownloadException implements Exception {
  const MediaDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
