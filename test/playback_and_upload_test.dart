// ============================================================================
//  ENNVO — THE NEW PIECES
//
//  The tests of the pieces that arrived with the reels round: the playback
//  handle of the feed, the signature of the Cloudflare uploads and the
//  brand assets.
// ============================================================================

import 'dart:io';

import 'package:ennvo/data/services/upload_service.dart';
import 'package:ennvo/features/reels/widgets/reel_video.dart';
import 'package:ennvo/shared/widgets/brand_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the playback handle of the feed', () {
    test('the reel runs at its normal speed to begin with', () {
      final playback = ReelPlayback();
      addTearDown(playback.dispose);

      expect(playback.speed, 1);
      expect(playback.pendingSeek, isNull);
    });

    test('the 2x hold sets the speed and gives it back', () {
      final playback = ReelPlayback();
      addTearDown(playback.dispose);

      playback.setSpeed(2);
      expect(playback.speed, 2);

      playback.setSpeed(1);
      expect(playback.speed, 1);
    });

    test('the speed is only written when it really changes', () {
      final playback = ReelPlayback();
      addTearDown(playback.dispose);

      var told = 0;
      playback.addListener(() => told++);

      playback.setSpeed(1);
      expect(told, 0, reason: 'the same speed is not a change');

      playback.setSpeed(2);
      expect(told, 1);
    });

    test('a scrub is kept until the reel on screen takes it', () {
      final playback = ReelPlayback();
      addTearDown(playback.dispose);

      playback.seek(0.42);
      expect(playback.pendingSeek, closeTo(0.42, 0.0001));

      // A neighbouring reel must not swallow it.
      playback.consumeSeek();
      expect(playback.pendingSeek, isNull);
    });

    test('a scrub is clamped inside the reel', () {
      final playback = ReelPlayback();
      addTearDown(playback.dispose);

      playback.seek(-3);
      expect(playback.pendingSeek, 0);

      playback.seek(9);
      expect(playback.pendingSeek, 1);
    });
  });

  group('the Cloudflare uploads', () {
    test('the public address of a file is built from the domain', () {
      expect(
        UploadService.publicUrl('reels/abc.mp4'),
        endsWith('/reels/abc.mp4'),
      );
      expect(
        UploadService.publicUrl('reels/abc.mp4'),
        isNot(contains('//reels')),
      );
    });

    test('a build without the credentials says so', () {
      // The test build carries no credentials, so the upload must report
      // that it is not configured instead of failing with a crash.
      expect(UploadService.isConfigured, isFalse);
    });

    test('the signature is the one of the reference implementation', () {
      // The vector comes from `tooling/make_r2_test_vector.py`. If the
      // signature of the app ever drifts away from it, the uploads stop
      // working - and this test says so before the build reaches a phone.
      final authorization = UploadService.testAuthorization(
        account: 'f45c8ffc24470718062d4b2eab12c2cd',
        bucket: 'ennvo-storage',
        key: 'reels/test-vector.mp4',
        contentType: 'video/mp4',
        body: 'ennvo signature test vector'.codeUnits,
        timestamp: '20240102T030405Z',
        accessKey: 'AKIATESTVECTOR00000',
        secretKey: 'test-vector-secret-key-0000000000000000000',
      );

      expect(
        authorization,
        'AWS4-HMAC-SHA256 '
        'Credential=AKIATESTVECTOR00000/20240102/auto/s3/aws4_request, '
        'SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, '
        'Signature=17e5bfe13103d5a7bc499448391edf10441c16037b9a665f96503f8822459903',
      );
    });
  });

  group('the brand assets', () {
    test('the black tile of the logo is there and it is opaque', () {
      final file = File('assets/brand/ennvo_logo_on_black.png');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      // The PNG signature.
      expect(bytes.sublist(0, 8), [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
    });

    test('the splash is pure black, like the Android window', () {
      expect(kEnnvoSplashBlack, const Color(0xFF000000));
    });

    test('the white mark the splash draws is there', () {
      final file = File('assets/brand/ennvo_mark_white.png');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });
  });
}
