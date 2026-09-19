class Profile {
  final String id;
  final String fullName;
  final int? age;
  final String? gender;
  final String? city;
  final String? avatarUrl;
  final String? bio;
  final double reliabilityScore;

  Profile({
    required this.id,
    required this.fullName,
    this.age,
    this.gender,
    this.city,
    this.avatarUrl,
    this.bio,
    this.reliabilityScore = 100,
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
      );

  Map<String, dynamic> toUpdateMap() => {
        'full_name': fullName,
        'age': age,
        'gender': gender,
        'city': city,
        'avatar_url': avatarUrl,
        'bio': bio,
      };
}
