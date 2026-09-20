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

  /// Up to 3 interests picked from the fixed list in interest.dart.
  final List<String> interests;

  /// 'de', 'en', or 'other'.
  final String? language;

  /// Chats with no new message for 7 days get archived automatically.
  final bool autoArchiveInactiveChats;

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
    this.interests = const [],
    this.language,
    this.autoArchiveInactiveChats = false,
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
    interests: (map['interests'] as List?)?.cast<String>() ?? const [],
    language: map['language'] as String?,
    autoArchiveInactiveChats:
        map['auto_archive_inactive_chats'] as bool? ?? false,
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
    String? language,
    bool? autoArchiveInactiveChats,
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
    interests: interests ?? this.interests,
    language: language ?? this.language,
    autoArchiveInactiveChats:
        autoArchiveInactiveChats ?? this.autoArchiveInactiveChats,
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
    'language': language,
    'auto_archive_inactive_chats': autoArchiveInactiveChats,
  };
}
