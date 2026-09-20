import '../models/profile.dart';

/// Whether [other] may be shown to [me] as a match/discovery candidate,
/// respecting both people's gender preference (only ever "same gender
/// only" or "no restriction" — never "opposite gender only") and [me]'s
/// preferred age range.
bool isAllowedByPreferences(Profile me, Profile other) {
  if (me.gender != null && other.gender != null && me.gender != other.gender) {
    if (me.genderPreference == 'same_only') return false;
    if (other.genderPreference == 'same_only') return false;
  }
  if (other.age != null) {
    if (me.ageRangeMin != null && other.age! < me.ageRangeMin!) return false;
    if (me.ageRangeMax != null && other.age! > me.ageRangeMax!) return false;
  }
  return true;
}
