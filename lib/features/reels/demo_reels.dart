// ============================================================================
//  ENNVO — REEL DEMO CONTENT
//
//  The reels feed falls back to this small local set when the account has no
//  reels yet, so the screen is never an empty box — and so the golden
//  renders have something to draw.
//
//  The videos and posters are the ones from the reels prototype.
// ============================================================================

import '../../data/models/post.dart';

class DemoReel {
  const DemoReel({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.authorRole,
    required this.caption,
    required this.tags,
    required this.songTitle,
    required this.songArtist,
    required this.videoAsset,
    required this.posterAsset,
    required this.likes,
    required this.comments,
    required this.favourites,
    required this.shares,
    required this.views,
  });

  final String id;
  final String authorName;
  final String authorHandle;
  final String authorRole;
  final String caption;
  final String tags;
  final String songTitle;
  final String songArtist;
  final String videoAsset;
  final String posterAsset;
  final int likes;
  final int comments;
  final int favourites;
  final int shares;
  final int views;
}

const List<DemoReel> kDemoReels = [
  DemoReel(
    id: 'demo-reel-1',
    authorName: 'Nila Rahman',
    authorHandle: 'nila.rahman',
    authorRole: 'Visual storyteller',
    caption:
        'সন্ধ্যার ছাদে এক কাপ চা, আর শান্ত হয়ে আসা শহরের আলো',
    tags: '#rooftop #dhaka #goldenhour',
    songTitle: 'Borshar Gaan',
    songArtist: 'original audio',
    videoAsset: 'assets/demo/reels/r1.mp4',
    posterAsset: 'assets/demo/reels/r1.jpg',
    likes: 24800,
    comments: 1320,
    favourites: 3900,
    shares: 940,
    views: 184000,
  ),
  DemoReel(
    id: 'demo-reel-2',
    authorName: 'Arif Hasan',
    authorHandle: 'arif.hasan',
    authorRole: 'Street photographer',
    caption:
        'বৃষ্টির পরে পুরান ঢাকার গলিতে হারিয়ে যাওয়া এক বিকেল',
    tags: '#oldDhaka #rain #streets',
    songTitle: 'Shohor Er Gaan',
    songArtist: 'Arif Hasan',
    videoAsset: 'assets/demo/reels/r2.mp4',
    posterAsset: 'assets/demo/reels/r2.jpg',
    likes: 12400,
    comments: 860,
    favourites: 2100,
    shares: 410,
    views: 91000,
  ),
  DemoReel(
    id: 'demo-reel-3',
    authorName: 'Tania Akter',
    authorHandle: 'tania.akter',
    authorRole: 'Travel creator',
    caption: 'কক্সবাজারের সূর্যাস্ত, যেটা ক্যামেরায় ধরা যায় না',
    tags: '#coxsbazar #sunset #travel',
    songTitle: 'Shagor Dhewa',
    songArtist: 'original audio',
    videoAsset: 'assets/demo/reels/r3.mp4',
    posterAsset: 'assets/demo/reels/r3.jpg',
    likes: 58200,
    comments: 3400,
    favourites: 9800,
    shares: 2600,
    views: 412000,
  ),
  DemoReel(
    id: 'demo-reel-4',
    authorName: 'Rafi Ahmed',
    authorHandle: 'rafi.ahmed',
    authorRole: 'Filmmaker',
    caption: 'রাতের শহর, নিয়ন আলো আর এক টুকরো নীরবতা',
    tags: '#nightcity #cinematic #film',
    songTitle: 'Nishi Raat',
    songArtist: 'Rafi Ahmed',
    videoAsset: 'assets/demo/reels/r4.mp4',
    posterAsset: 'assets/demo/reels/r4.jpg',
    likes: 9100,
    comments: 420,
    favourites: 1500,
    shares: 230,
    views: 63000,
  ),
];

/// Converts the demo set into the post model the feed renders.
List<AppPost> demoReelsAsPosts() => [
  for (final reel in kDemoReels)
    AppPost(
      id: reel.id,
      authorId: 'demo-${reel.authorHandle}',
      authorName: reel.authorName,
      authorUsername: reel.authorHandle,
      authorAvatar: '',
      text: '${reel.caption}\n${reel.tags}',
      media: const [],
      type: PostType.reel,
      likesCount: reel.likes,
      commentsCount: reel.comments,
      favoritesCount: reel.favourites,
      repostsCount: reel.shares,
      viewsCount: reel.views,
      songTitle: reel.songTitle,
      songArtist: reel.songArtist,
      category: 'Trending',
      thumbnailUrl: reel.posterAsset,
      createdAt: DateTime(2026),
    ),
];

/// The demo reel for a post id — used by the reel card to find its local
/// video asset.
DemoReel? demoReelFor(String postId) {
  for (final reel in kDemoReels) {
    if (reel.id == postId) return reel;
  }
  return null;
}
