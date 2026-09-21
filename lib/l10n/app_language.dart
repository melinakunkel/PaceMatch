enum AppLanguage {
  de,
  en;

  String get label => switch (this) {
    AppLanguage.de => 'Deutsch',
    AppLanguage.en => 'English',
  };

  static AppLanguage fromCode(String? code) => switch (code) {
    'en' => AppLanguage.en,
    _ => AppLanguage.de,
  };
}
