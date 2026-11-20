// ============================================================================
//  ENNVO �?" UPLOAD SERVICE
//
//  The uploads of the app go to Cloudflare R2.
//
//  R2 speaks the S3 protocol, so an upload is a signed `PUT`. The
//  signature is the AWS Signature Version 4, with the region `auto` that
//  R2 asks for.
//
//  The credentials never live in the source. They are compiled into the
//  build from the GitHub secrets:
//
//      flutter build apk \
//        --dart-define=CLOUDFLARE_ACCOUNT_ID=... \
//        --dart-define=CLOUDFLARE_R2_ACCESS_KEY_ID=... \
//        --dart-define=CLOUDFLARE_R2_SECRET_ACCESS_KEY=... \
//        --dart-define=CLOUDFLARE_R2_BUCKET_NAME=... \
//        --dart-define=CLOUDFLARE_R2_PUBLIC_DOMAIN=...
//
//  A build without them still runs: the upload reports that it is not
//  configured instead of failing with a crash.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// How an upload is going.
typedef UploadProgress = void Function(int sent, int total);

class UploadResult {
  const UploadResult({required this.url, required this.key});

  /// The public address of the file.
  final String url;

  /// The key of the file inside the bucket.
  final String key;
}

class UploadException implements Exception {
  const UploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UploadService {
  const UploadService._();

  // ---------------------------------------------------------------------
  //  The configuration, read from the build
  // ---------------------------------------------------------------------
  static const String accountId =
      String.fromEnvironment('CLOUDFLARE_ACCOUNT_ID');
  static const String accessKeyId =
      String.fromEnvironment('CLOUDFLARE_R2_ACCESS_KEY_ID');
  static const String secretAccessKey =
      String.fromEnvironment('CLOUDFLARE_R2_SECRET_ACCESS_KEY');
  static const String bucketName =
      String.fromEnvironment('CLOUDFLARE_R2_BUCKET_NAME');
  static const String publicDomain =
      String.fromEnvironment('CLOUDFLARE_R2_PUBLIC_DOMAIN');

  /// Whether the build carries the credentials of the bucket.
  static bool get isConfigured =>
      accountId.isNotEmpty &&
      accessKeyId.isNotEmpty &&
      secretAccessKey.isNotEmpty &&
      bucketName.isNotEmpty;

  /// The address the file is served from.
  static String publicUrl(String key) {
    final base = publicDomain.replaceAll(RegExp(r'/+$'), '');
    return '$base/$key';
  }

  /// The address the upload is sent to.
  static Uri _endpoint(String key) {
    return Uri.parse(
      'https://$accountId.r2.cloudflarestorage.com/$bucketName/$key',
    );
  }

  // ---------------------------------------------------------------------
  //  The uploads
  // ---------------------------------------------------------------------

  /// Uploads a cross-platform [XFile] (Web + Android + iOS).
  static Future<UploadResult> uploadXFile({
    required XFile file,
    required String folder,
    String? contentType,
    UploadProgress? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    final rawName = file.name.isNotEmpty ? file.name : file.path;
    final extension = _extensionOf(rawName);
    final key = '$folder/${DateTime.now().millisecondsSinceEpoch}'
        '-${_randomId()}.$extension';

    return uploadBytes(
      bytes: bytes,
      key: key,
      contentType: contentType ?? _contentTypeOf(extension),
      onProgress: onProgress,
    );
  }

  /// Uploads a file of the device.
  ///
  /// [folder] is the first part of the key: `reels`, `posts`, `voice` or
  /// `avatars`.
  static Future<UploadResult> uploadFile({
    required File file,
    required String folder,
    String? contentType,
    UploadProgress? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    final extension = _extensionOf(file.path);
    final key = '$folder/${DateTime.now().millisecondsSinceEpoch}'
        '-${_randomId()}.$extension';

    return uploadBytes(
      bytes: bytes,
      key: key,
      contentType: contentType ?? _contentTypeOf(extension),
      onProgress: onProgress,
    );
  }

  /// Uploads bytes that are already in memory.
  static Future<UploadResult> uploadBytes({
    required Uint8List bytes,
    required String key,
    required String contentType,
    UploadProgress? onProgress,
  }) async {
    if (!isConfigured) {
      throw const UploadException(
        'The uploads are not configured in this build.',
      );
    }

    final uri = _endpoint(key);
    final payload = sha256.convert(bytes).toString();
    final now = DateTime.now().toUtc();
    final stamp = _timestamp(now);

    final headers = <String, String>{
      'host': uri.host,
      'x-amz-content-sha256': payload,
      'x-amz-date': stamp,
      'content-type': contentType,
    };

    final authorization = _authorization(
      uri: uri,
      headers: headers,
      payload: payload,
      stamp: stamp,
      accessKey: accessKeyId,
      secretKey: secretAccessKey,
    );

    final client = http.Client();
    try {
      final request = http.Request('PUT', uri)
        ..headers.addAll({
          ...headers,
          'authorization': authorization,
        })
        ..bodyBytes = bytes;

      if (onProgress == null) {
        final response = await client.send(request);
        final body = await response.stream.bytesToString();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw UploadException(
            'The upload failed (${response.statusCode}): $body',
          );
        }
      } else {
        // The upload is sent in pieces, so the bar of the sheet can show
        // how far it has come.
        final total = bytes.length;
        final streamed = http.StreamedRequest('PUT', uri)
          ..headers.addAll({
            ...headers,
            'authorization': authorization,
            'content-length': '$total',
          });

        const chunk = 64 * 1024;
        for (var offset = 0; offset < total; offset += chunk) {
          final end = offset + chunk < total ? offset + chunk : total;
          streamed.sink.add(Uint8List.sublistView(bytes, offset, end));
          onProgress(end, total);
        }
        await streamed.sink.close();

        final response = await client.send(streamed);
        final body = await response.stream.bytesToString();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw UploadException(
            'The upload failed (${response.statusCode}): $body',
          );
        }
      }
    } on UploadException {
      rethrow;
    } catch (error) {
      throw UploadException('The upload failed: $error');
    } finally {
      client.close();
    }

    return UploadResult(url: publicUrl(key), key: key);
  }

  // ---------------------------------------------------------------------
  //  The signature
  // ---------------------------------------------------------------------

  /// The `Authorization` header of an upload.
  ///
  /// It is the AWS Signature Version 4, with the region `auto` that R2 asks
  /// for.
  static String _authorization({
    required Uri uri,
    required Map<String, String> headers,
    required String payload,
    required String stamp,
    required String accessKey,
    required String secretKey,
  }) {
    const service = 's3';
    const region = 'auto';
    const algorithm = 'AWS4-HMAC-SHA256';

    final date = stamp.substring(0, 8);
    final scope = '$date/$region/$service/aws4_request';

    final signedHeaders = headers.keys.toList()..sort();
    final canonicalHeaders = signedHeaders
        .map((key) => '$key:${headers[key]!.trim()}\n')
        .join();
    final signedHeaderList = signedHeaders.join(';');

    final canonicalRequest = [
      'PUT',
      uri.path,
      uri.query.isEmpty ? '' : uri.query,
      canonicalHeaders,
      signedHeaderList,
      payload,
    ].join('\n');

    final stringToSign = [
      algorithm,
      stamp,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signature = _hmacHex(
      _signingKey(date, region, service, secretKey),
      stringToSign,
    );

    return '$algorithm '
        'Credential=$accessKey/$scope, '
        'SignedHeaders=$signedHeaderList, '
        'Signature=$signature';
  }

  /// The signature of a fixed upload.
  ///
  /// It is the test vector of the app: the test compares it with the
  /// signature the reference implementation builds, so the two can never
  /// drift apart.
  ///
  /// The account, the bucket, the key and the secret are given, because the
  /// test build carries no credentials of its own.
  @visibleForTesting
  static String testAuthorization({
    required String account,
    required String bucket,
    required String key,
    required String contentType,
    required List<int> body,
    required String timestamp,
    required String accessKey,
    required String secretKey,
  }) {
    final uri = Uri.parse(
      'https://$account.r2.cloudflarestorage.com/$bucket/$key',
    );
    final payload = sha256.convert(body).toString();

    return _authorization(
      uri: uri,
      headers: {
        'host': uri.host,
        'x-amz-content-sha256': payload,
        'x-amz-date': timestamp,
        'content-type': contentType,
      },
      payload: payload,
      stamp: timestamp,
      accessKey: accessKey,
      secretKey: secretKey,
    );
  }

  static Uint8List _signingKey(
    String date,
    String region,
    String service,
    String secretKey,
  ) {
    final key = _hmac(
      utf8.encode('AWS4$secretKey'),
      utf8.encode(date),
    );
    final key2 = _hmac(key, utf8.encode(region));
    final key3 = _hmac(key2, utf8.encode(service));
    return _hmac(key3, utf8.encode('aws4_request'));
  }

  static Uint8List _hmac(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  static String _hmacHex(List<int> key, String data) {
    return _hmac(key, utf8.encode(data))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// The timestamp of the signature: `20240102T030405Z`.
  static String _timestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        'T${two(time.hour)}${two(time.minute)}${two(time.second)}Z';
  }

  // ---------------------------------------------------------------------
  //  The names
  // ---------------------------------------------------------------------
  static String _randomId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$stamp${DateTime.now().hashCode.toRadixString(36)}';
  }

  static String _extensionOf(String path) {
    final slash = path.lastIndexOf('/');
    final name = slash >= 0 ? path.substring(slash + 1) : path;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'bin';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeOf(String extension) {
    switch (extension) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}
