// ============================================================================
//  ENNVO — USER MODEL
//
//  A direct port of the `User` interface in `src/types/index.ts`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parse.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.avatar,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    this.mobileNumber,
    this.phoneNumber,
    this.bannerUrl,
    this.gender,
    this.dob,
    this.location,
    this.link,
    this.isVerified = false,
    this.isPrivate = false,
    this.passkeyEnabled = false,
    this.verificationStatus,
    this.whoCanComment,
    this.whoCanMention,
    this.whoCanMessage,
    this.offensiveFilter = false,
    this.filterMessageRequests = false,
    this.readReceipts = true,
    this.blockedUserIds = const [],
    this.highlights = const [],
    this.statusNote,
    this.hasPassword = false,
    this.authProvider,
    this.accountType = 'personal',
    this.isAdmin = false,
    this.role,
    this.isBanned = false,
    this.banReason,
    this.bannedUntil,
    this.notifMode = 'on',
    this.createdAt,
  });

  final String uid;
  final String name;
  final String username;
  final String email;
  final String avatar;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int postsCount;

  final String? mobileNumber;
  final String? phoneNumber;
  final String? bannerUrl;
  final String? gender;
  final String? dob;
  final String? location;
  final String? link;

  final bool isVerified;
  final bool isPrivate;
  final bool passkeyEnabled;
  final String? verificationStatus;

  final String? whoCanComment;
  final String? whoCanMention;
  final String? whoCanMessage;

  final bool offensiveFilter;
  final bool filterMessageRequests;
  final bool readReceipts;

  final List<String> blockedUserIds;
  final List<String> highlights;
  final String? statusNote;
  final bool hasPassword;
  final String? authProvider;
  final String accountType;
  final bool isAdmin;
  final String? role;
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedUntil;
  final String notifMode;
  final DateTime? createdAt;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? fallbackId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: (data['uid'] as String?) ?? fallbackId ?? doc.id,
      name: (data['name'] as String?) ??
          (data['displayName'] as String?) ??
          '',
      username: (data['username'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      avatar: (data['avatar'] as String?) ??
          (data['photoURL'] as String?) ??
          '',
      bio: (data['bio'] as String?) ?? '',
      followersCount: parseInt(data['followersCount']),
      followingCount: parseInt(data['followingCount']),
      postsCount: parseInt(data['postsCount']),
      mobileNumber: data['mobileNumber'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      gender: data['gender'] as String?,
      dob: data['dob'] as String?,
      location: data['location'] as String?,
      link: data['link'] as String?,
      isVerified: data['isVerified'] == true || data['verified'] == true,
      isPrivate: data['isPrivate'] == true,
      passkeyEnabled: data['passkeyEnabled'] == true,
      verificationStatus: data['verificationStatus'] as String?,
      whoCanComment: data['whoCanComment'] as String?,
      whoCanMention: data['whoCanMention'] as String?,
      whoCanMessage: data['whoCanMessage'] as String?,
      offensiveFilter: data['offensiveFilter'] == true,
      filterMessageRequests: data['filterMessageRequests'] == true,
      readReceipts: data['readReceipts'] as bool? ?? true,
      blockedUserIds: parseStringList(data['blockedUserIds']),
      highlights: parseStringList(data['highlights']),
      statusNote: data['statusNote'] as String?,
      hasPassword: data['hasPassword'] == true,
      authProvider: data['authProvider'] as String?,
      accountType: data['accountType'] as String? ?? 'personal',
      isAdmin: data['isAdmin'] == true,
      role: data['role'] as String?,
      isBanned: data['isBanned'] == true,
      banReason: data['banReason'] as String?,
      bannedUntil: parseDateTime(data['bannedUntil']),
      notifMode: data['notifMode'] as String? ?? 'on',
      createdAt: parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'name': name,
    'username': username,
    'email': email,
    'avatar': avatar,
    'bio': bio,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'postsCount': postsCount,
    'isVerified': isVerified,
    'isPrivate': isPrivate,
    'highlights': highlights,
    'notifMode': notifMode,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? avatar,
    String? bio,
    String? bannerUrl,
    String? link,
    String? location,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isVerified,
    bool? isPrivate,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      mobileNumber: mobileNumber,
      phoneNumber: phoneNumber,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      gender: gender,
      dob: dob,
      location: location ?? this.location,
      link: link ?? this.link,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      passkeyEnabled: passkeyEnabled,
      verificationStatus: verificationStatus,
      whoCanComment: whoCanComment,
      whoCanMention: whoCanMention,
      whoCanMessage: whoCanMessage,
      offensiveFilter: offensiveFilter,
      filterMessageRequests: filterMessageRequests,
      readReceipts: readReceipts,
      blockedUserIds: blockedUserIds,
      highlights: highlights,
      statusNote: statusNote,
      hasPassword: hasPassword,
      authProvider: authProvider,
      accountType: accountType,
      isAdmin: isAdmin,
      role: role,
      isBanned: isBanned,
      banReason: banReason,
      bannedUntil: bannedUntil,
      notifMode: notifMode,
      createdAt: createdAt,
    );
  }
}
