import 'prompt.dart';

class Profile {
  final String id;
  final String fullName;
  final int? age;
  final String? gender;
  final String? city;
  final String? avatarUrl;
  final String? bio;
  final double reliabilityScore;

  /// 'same_only' restricts matches to people who share [gender]; anything
  /// else (including null) means no restriction ("egal"). There is
  /// intentionally no "only the other gender" option.
  final String? genderPreference;
  final int? ageRangeMin;
  final int? ageRangeMax;
  final bool isVerified;

  /// Hidden from matching/discovery once enough reports have come in
  /// against this account — see handle_new_report() in the DB.
  final bool isSuspended;

  /// Up to 3 interests picked from the fixed list in interest.dart.
  final List<String> interests;

  /// Any of 'de', 'en', 'other' — multiple selectable.
  final List<String> languages;

  /// Chats with no new message for 7 days get archived automatically.
  final bool autoArchiveInactiveChats;

  /// Up to [kMaxPrompts] short Q&A prompts, Hinge-style.
  final List<ProfilePrompt> prompts;

  /// [fullName] minus the last name — shown to everyone except the profile's
  /// own owner, since a stranger from a match doesn't need your surname.
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  Profile({
    required this.id,
    required this.fullName,
    this.age,
    this.gender,
    this.city,
    this.avatarUrl,
    this.bio,
    this.reliabilityScore = 100,
    this.genderPreference,
    this.ageRangeMin,
    this.ageRangeMax,
    this.isVerified = false,
    this.isSuspended = false,
    this.interests = const [],
    this.languages = const [],
    this.autoArchiveInactiveChats = false,
    this.prompts = const [],
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String,
    fullName: map['full_name'] as String? ?? 'Unbekannt',
    age: map['age'] as int?,
    gender: map['gender'] as String?,
    city: map['city'] as String?,
    avatarUrl: map['avatar_url'] as String?,
    bio: map['bio'] as String?,
    reliabilityScore: (map['reliability_score'] as num?)?.toDouble() ?? 100,
    genderPreference: map['gender_preference'] as String?,
    ageRangeMin: map['age_range_min'] as int?,
    ageRangeMax: map['age_range_max'] as int?,
    isVerified: map['is_verified'] as bool? ?? false,
    isSuspended: map['is_suspended'] as bool? ?? false,
    interests: (map['interests'] as List?)?.cast<String>() ?? const [],
    languages: (map['languages'] as List?)?.cast<String>() ?? const [],
    autoArchiveInactiveChats:
        map['auto_archive_inactive_chats'] as bool? ?? false,
    prompts:
        (map['prompts'] as List?)
            ?.map((p) => ProfilePrompt.fromMap(p as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  /// Note: passing null for a nullable field keeps the current value — this
  /// can't clear one. Build a [Profile] directly when a field needs clearing
  /// (e.g. genderPreference, ageRangeMin/Max).
  Profile copyWith({
    String? fullName,
    int? age,
    String? gender,
    String? city,
    String? avatarUrl,
    String? bio,
    String? genderPreference,
    int? ageRangeMin,
    int? ageRangeMax,
    List<String>? interests,
    List<String>? languages,
    bool? autoArchiveInactiveChats,
    List<ProfilePrompt>? prompts,
  }) => Profile(
    id: id,
    fullName: fullName ?? this.fullName,
    age: age ?? this.age,
    gender: gender ?? this.gender,
    city: city ?? this.city,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    reliabilityScore: reliabilityScore,
    genderPreference: genderPreference ?? this.genderPreference,
    ageRangeMin: ageRangeMin ?? this.ageRangeMin,
    ageRangeMax: ageRangeMax ?? this.ageRangeMax,
    isVerified: isVerified,
    isSuspended: isSuspended,
    interests: interests ?? this.interests,
    languages: languages ?? this.languages,
    autoArchiveInactiveChats:
        autoArchiveInactiveChats ?? this.autoArchiveInactiveChats,
    prompts: prompts ?? this.prompts,
  );

  Map<String, dynamic> toUpdateMap() => {
    'full_name': fullName,
    'age': age,
    'gender': gender,
    'city': city,
    'avatar_url': avatarUrl,
    'bio': bio,
    'gender_preference': genderPreference,
    'age_range_min': ageRangeMin,
    'age_range_max': ageRangeMax,
    'interests': interests,
    'languages': languages,
    'auto_archive_inactive_chats': autoArchiveInactiveChats,
    'prompts': prompts.map((p) => p.toMap()).toList(),
  };
}
