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
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? 'Unbekannt',
        age: map['age'] as int?,
        gender: map['gender'] as String?,
        city: map['city'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        bio: map['bio'] as String?,
        reliabilityScore:
            (map['reliability_score'] as num?)?.toDouble() ?? 100,
        genderPreference: map['gender_preference'] as String?,
        ageRangeMin: map['age_range_min'] as int?,
        ageRangeMax: map['age_range_max'] as int?,
        isVerified: map['is_verified'] as bool? ?? false,
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
      };
}
