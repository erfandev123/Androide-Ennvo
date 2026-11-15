// ============================================================================
//  ENNVO — SONG MODEL
//
//  A direct port of the `Song` interface in `src/types/index.ts`.
//
//  A reel only stores the id of its song. The title, the artist and the
//  audio live in the `songs` collection, so the feed has to look them up —
//  exactly what the web app does in `ReelItem.tsx`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class AppSong {
  const AppSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    this.thumbnail,
    this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final String url;
  final String? thumbnail;
  final int? duration;

  /// The label the marquee shows — `title · artist`, or just the title.
  String get label => artist.isEmpty ? title : '$title · $artist';

  factory AppSong.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? fallbackId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppSong(
      id: (data['id'] as String?) ?? fallbackId ?? doc.id,
      title: (data['title'] as String?) ?? '',
      artist: (data['artist'] as String?) ?? '',
      url: (data['url'] as String?) ?? '',
      thumbnail: data['thumbnail'] as String?,
      duration: (data['duration'] as num?)?.toInt(),
    );
  }
}
