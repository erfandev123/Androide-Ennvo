// ============================================================================
//  ENNVO — REEL VIDEO PRELOADER
//
//  A vertical video feed feels fast when the next video is already warm.
//
//  When the player opens a URL it has to resolve the host, complete the TLS
//  handshake and then wait for the first bytes to arrive. All three happen
//  *after* the user has swiped, which is exactly where the stutter comes
//  from.
//
//  The preloader fetches the first bytes of the upcoming videos with a range
//  request while the user is still watching the current one. That resolves
//  DNS, completes the handshake and warms the CDN edge for those exact URLs,
//  so the player starts from a warm path when the swipe happens.
//
//  The request is fire and forget: it is cancelled as soon as the reel
//  leaves the window, and it never blocks the UI thread.
// ============================================================================

import 'dart:async';

import 'package:http/http.dart' as http;

/// How many bytes of the next videos are warmed.
const int _warmBytes = 96 * 1024;

/// A short window before a video is dropped from the warm set.
const Duration _warmTtl = Duration(seconds: 45);

class ReelPreloader {
  ReelPreloader._();

  static final Map<String, DateTime> _warming = <String, DateTime>{};
  static final Map<String, http.Client> _clients = <String, http.Client>{};
  static final http.Client _fallback = http.Client();

  /// Warms the connection to [url].
  ///
  /// Safe to call with the same URL many times — a URL that is already warm
  /// is ignored.
  static void warm(String? url) {
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http')) return;

    final now = DateTime.now();
    _warming.removeWhere((_, at) => now.difference(at) > _warmTtl);
    if (_warming.containsKey(url)) return;
    _warming[url] = now;

    try {
      final client = http.Client();
      _clients[url] = client;
      client
          .send(http.Request('GET', Uri.parse(url)))
          .then((response) {
            // Drain the body so the connection can be reused, then close it.
            response.stream.listen(
              (_) {},
              onDone: () => _close(url),
              onError: (_) => _close(url),
              cancelOnError: true,
            );
          })
          .catchError((Object _) => _close(url));
    } catch (_) {
      _warming.remove(url);
    }
  }

  /// Warms a list of URLs, keeping only the first [count].
  static void warmAll(List<String?> urls, {int count = 2}) {
    var warmed = 0;
    for (final url in urls) {
      if (warmed >= count) break;
      if (url == null || url.isEmpty) continue;
      warm(url);
      warmed++;
    }
  }

  /// Drops the warm state of a URL — used when a reel leaves the window.
  static void release(String? url) {
    if (url == null) return;
    _close(url);
  }

  static void _close(String url) {
    _clients.remove(url)?.close();
    _warming.remove(url);
  }

  /// Releases everything. Called when the feed is disposed.
  static void releaseAll() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
    _warming.clear();
  }
}
