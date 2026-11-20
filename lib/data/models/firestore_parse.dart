// ============================================================================
//  ENNVO — FIRESTORE PARSING HELPERS
//
//  Shared defensive parsers so documents written by the React web app
//  (which can carry Firestore Timestamps, serialized {_seconds} maps, epoch
//  millis/seconds, or ISO strings) never fail to decode or get dropped.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) {
    // Values under 100 billion are Unix seconds; otherwise milliseconds.
    final ms = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (value is num) {
    final raw = value.toInt();
    final ms = raw.abs() < 100000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return parseDateTime(asInt);
    return DateTime.tryParse(trimmed);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
    if (seconds is num) {
      final ms = seconds.toInt() * 1000 +
          (nanos is num ? nanos.toInt() ~/ 1000000 : 0);
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }
  return null;
}

int parseInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

List<String> parseStringList(dynamic value) {
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    if (item is String && item.isNotEmpty) {
      result.add(item);
    } else if (item is Map && item['url'] is String) {
      final url = item['url'] as String;
      if (url.isNotEmpty) result.add(url);
    }
  }
  return result;
}
