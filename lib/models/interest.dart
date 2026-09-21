import '../l10n/strings.dart';

/// Fixed set of interests users can pick from on their profile — kept short
/// and general so overlaps are meaningful, not a free-text tag cloud. These
/// are the raw values stored on a profile; [interestLabel] (in
/// display_labels.dart) translates them for display without changing what's
/// stored.
const kInterestOptions = [
  'Reisen',
  'Musik',
  'Kochen & Backen',
  'Lesen',
  'Fotografie',
  'Filme & Serien',
  'Kunst & Kultur',
  'Gaming',
  'Natur & Outdoor',
  'Yoga & Meditation',
  'Ernährung',
  'Tiere',
  'Café & Brunch',
  'Festivals & Konzerte',
  'Nachhaltigkeit',
];

const kMaxInterests = 3;

/// Not `const` so it always reflects the active language — still usable as
/// `kLanguageOptions[code]` / `kLanguageOptions.entries` exactly like a
/// plain map.
Map<String, String> get kLanguageOptions => {
  'de': t('language.de'),
  'en': t('language.en'),
  'other': t('language.other'),
};
