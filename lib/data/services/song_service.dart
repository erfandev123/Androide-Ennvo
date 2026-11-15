// ============================================================================
//  ENNVO — SONG SERVICE
//
//  Reads the `songs` collection, the same collection the web app reads in
//  `src/services/postService.ts`.
//
//  A reel stores the id of its song, so the title, the artist and the audio
//  are looked up here. The lookup is cached by the caller, because the same
//  song shows up on reel after reel.
// ============================================================================

import '../models/song.dart';
import 'firebase_service.dart';

class SongService {
  const SongService._();

  /// Fetches one song by its id.
  ///
  /// It never throws: a missing song is simply a reel without a song.
  static Future<AppSong?> fetch(String songId) async {
    if (songId.isEmpty) return null;
    if (!FirebaseService.isReady) return null;
    try {
      final doc = await FirebaseService.firestore
          .collection('songs')
          .doc(songId)
          .get();
      if (!doc.exists) return null;
      return AppSong.fromFirestore(doc, fallbackId: songId);
    } catch (_) {
      return null;
    }
  }
}
