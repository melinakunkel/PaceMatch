import '../l10n/strings.dart';
import '../models/activity.dart' show weekdayLabels;

/// Translates a skill level stored in the database ('Anfänger',
/// 'Fortgeschritten', 'Profi' — the raw values never change, only how
/// they're displayed) into the active language.
String levelLabel(String level) => switch (level) {
  'Anfänger' => t('level.beginner'),
  'Fortgeschritten' => t('level.advanced'),
  'Profi' => t('level.pro'),
  _ => level,
};

/// Same idea for the gender values stored on a profile ('weiblich',
/// 'männlich', 'divers').
String genderLabel(String gender) => switch (gender) {
  'weiblich' => t('gender.female'),
  'männlich' => t('gender.male'),
  'divers' => t('gender.diverse'),
  _ => gender,
};

/// Same idea for the report reason stored on a report row.
String reportReasonLabel(String reason) => switch (reason) {
  'Belästigung' => t('report.harassment'),
  'Unangemessenes Verhalten' => t('report.inappropriateBehavior'),
  'Nicht erschienen' => t('report.noShow'),
  'Fake-Profil' => t('report.fakeProfile'),
  'Sonstiges' => t('report.other'),
  _ => reason,
};

/// Same idea for a profile prompt's question (see [kPromptQuestions] in
/// models/prompt.dart) — the stored question text stays German, only the
/// displayed label changes.
String promptQuestionLabel(String question) => switch (question) {
  'Mein Lieblings-Trainingsort ist...' => t('prompt.favoriteSpot'),
  'Du findest mich garantiert beim...' => t('prompt.youllFindMe'),
  'Nach dem Sport brauche ich unbedingt...' => t('prompt.afterSport'),
  'Mein verrücktestes Sport-Erlebnis...' => t('prompt.craziestExperience'),
  'Worauf ich beim Training am meisten achte...' => t('prompt.trainingFocus'),
  'Das würde ich gerne mal ausprobieren...' => t('prompt.wantToTry'),
  'Mein Trick, wenn ich keine Lust habe...' => t('prompt.motivationTrick'),
  'Perfektes Sport-Date für mich...' => t('prompt.perfectSportDate'),
  _ => question,
};

/// Same idea for an interest stored on a profile (see
/// [kInterestOptions] in models/interest.dart).
String interestLabel(String interest) => switch (interest) {
  'Reisen' => t('interest.travel'),
  'Musik' => t('interest.music'),
  'Kochen & Backen' => t('interest.cooking'),
  'Lesen' => t('interest.reading'),
  'Fotografie' => t('interest.photography'),
  'Filme & Serien' => t('interest.moviesSeries'),
  'Kunst & Kultur' => t('interest.artCulture'),
  'Gaming' => t('interest.gaming'),
  'Natur & Outdoor' => t('interest.natureOutdoors'),
  'Yoga & Meditation' => t('interest.yogaMeditation'),
  'Ernährung' => t('interest.nutrition'),
  'Tiere' => t('interest.animals'),
  'Café & Brunch' => t('interest.cafeBrunch'),
  'Festivals & Konzerte' => t('interest.festivalsConcerts'),
  'Nachhaltigkeit' => t('interest.sustainability'),
  _ => interest,
};

/// A meetup's date and time in local time, e.g. "Sa, 27.9. 09:00".
String formatMeetupTime(DateTime t) {
  final local = t.toLocal();
  final day = weekdayLabels[local.weekday - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$day, ${local.day}.${local.month}. $hh:$mm';
}

final _coordinates = RegExp(r'^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$');

/// Whether a stored place name is just raw coordinates ("47.80487,
/// 15.97940") — what older versions saved when the map point had no name.
bool isCoordinateName(String? name) =>
    name != null && _coordinates.hasMatch(name);

/// A place name for display: raw coordinates become "Punkt auf der Karte"
/// (the pin itself is still stored, so the map still opens at it).
String placeLabel(String name) =>
    isCoordinateName(name) ? t('location.pinOnMap') : name;
