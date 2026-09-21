import '../l10n/app_language.dart';
import '../services/locale_controller.dart';

/// Looks up [key] in the active language's dictionary (falling back to
/// German, then to the key itself if it's missing there too), and fills in
/// any `{placeholder}` markers from [args].
///
/// This is a plain function rather than something read off a BuildContext
/// because the whole app already rebuilds on a language change (see how
/// [LocaleController.language] is wired up in `app.dart`, the same pattern
/// used for [ThemeController]) — so every build() picks up the current
/// language automatically, with no context plumbing needed.
String t(String key, [Map<String, String>? args]) {
  final dict = LocaleController.language.value == AppLanguage.en ? _en : _de;
  var value = dict[key] ?? _de[key] ?? key;
  args?.forEach((k, v) => value = value.replaceAll('{$k}', v));
  return value;
}

const _de = <String, String>{
  // Shared across the auth flow / home.
  'app.tagline': 'Gemeinsam Sport machen, wenn es zeitlich passt.',

  // Login screen.
  'login.howItWorks': 'Wie funktioniert\'s?',
  'login.email': 'E-Mail',
  'login.emailInvalid': 'Gültige E-Mail eingeben',
  'login.password': 'Passwort',
  'login.passwordTooShort': 'Mind. 6 Zeichen',
  'login.rememberMe': 'Eingeloggt bleiben',
  'login.forgotPassword': 'Passwort vergessen?',
  'login.signInFailed': 'Anmeldung fehlgeschlagen: {error}',
  'login.signIn': 'Anmelden',
  'login.noAccount': 'Noch kein Konto? Jetzt registrieren',

  // Register screen.
  'register.title': 'Konto erstellen',
  'register.name': 'Name',
  'register.nameRequired': 'Name eingeben',
  'register.language': 'Sprache',
  'register.signUpFailed': 'Registrierung fehlgeschlagen: {error}',
  'register.submit': 'Registrieren',

  // Forgot-password dialog.
  'forgotPassword.title': 'Passwort vergessen?',
  'forgotPassword.sentMessage':
      'Falls ein Konto mit dieser E-Mail existiert, haben wir dir einen Link '
      'zum Zurücksetzen des Passworts geschickt. Schau auch im Spam-Ordner '
      'nach.',
  'forgotPassword.instructions':
      'Gib deine E-Mail-Adresse ein. Wir schicken dir einen Link, mit dem '
      'du ein neues Passwort festlegen kannst.',
  'forgotPassword.sendFailed': 'Konnte nicht gesendet werden: {error}',
  'forgotPassword.send': 'Link senden',
  'common.cancel': 'Abbrechen',
  'common.close': 'Schließen',

  // Reset-password screen.
  'resetPassword.title': 'Neues Passwort',
  'resetPassword.instructions': 'Bitte lege ein neues Passwort fest.',
  'resetPassword.newPassword': 'Neues Passwort',
  'resetPassword.confirmPassword': 'Passwort bestätigen',
  'resetPassword.mismatch': 'Passwörter stimmen nicht überein',
  'resetPassword.changeFailed': 'Änderung fehlgeschlagen: {error}',
  'resetPassword.changed': 'Passwort geändert.',
  'resetPassword.submit': 'Passwort ändern',

  // Settings screen.
  'settings.title': 'Einstellungen',
  'settings.help': 'Hilfe',
  'settings.howItWorks': 'So funktioniert SAMEPACE',
  'settings.tutorialSubtitle': 'Kurzes Tutorial ansehen',
  'settings.chats': 'Chats',
  'settings.autoArchiveDesc':
      'Chats ohne neue Nachricht seit 7 Tagen automatisch archivieren.',
  'settings.autoArchive': 'Automatisch archivieren',
  'settings.notifications': 'Benachrichtigungen',
  'settings.notificationsDescSupported':
      'Erhalte eine Browser-Benachrichtigung für neue Nachrichten und '
      'Sportbuddys, solange SAMEPACE in einem Tab offen ist.',
  'settings.notificationsDescUnsupported':
      'Dein Browser unterstützt keine Benachrichtigungen.',
  'settings.browserNotifications': 'Browser-Benachrichtigungen',
  'settings.permissionDenied':
      'Berechtigung nicht erteilt. Du kannst sie in den '
      'Browser-Einstellungen ändern.',
  'settings.design': 'Design',
  'settings.designDesc': 'Wähle den Look, der am besten zu dir passt.',
  'settings.language': 'Sprache',
  'settings.languageDesc': 'In welcher Sprache soll SAMEPACE angezeigt werden?',

  // Home screen.
  'home.question': 'Was möchtest du diese Woche machen?',
  'home.tutorialTooltip': 'Tutorial',

  // Bottom nav / app bar (AppScaffold).
  'nav.discover': 'Entdecken',
  'nav.plan': 'Plan',
  'nav.buddies': 'Buddys',
  'nav.chat': 'Chat',
  'nav.profile': 'Profil',
  'appbar.home': 'Home',
  'appbar.settings': 'Einstellungen',
};

const _en = <String, String>{
  'app.tagline': 'Do sport together, whenever the timing works.',

  'login.howItWorks': 'How does it work?',
  'login.email': 'Email',
  'login.emailInvalid': 'Enter a valid email',
  'login.password': 'Password',
  'login.passwordTooShort': 'At least 6 characters',
  'login.rememberMe': 'Stay signed in',
  'login.forgotPassword': 'Forgot password?',
  'login.signInFailed': 'Sign in failed: {error}',
  'login.signIn': 'Sign in',
  'login.noAccount': 'No account yet? Register now',

  'register.title': 'Create account',
  'register.name': 'Name',
  'register.nameRequired': 'Enter a name',
  'register.language': 'Language',
  'register.signUpFailed': 'Registration failed: {error}',
  'register.submit': 'Register',

  'forgotPassword.title': 'Forgot password?',
  'forgotPassword.sentMessage':
      'If an account exists for this email, we\'ve sent a link to reset '
      'the password. Check your spam folder too.',
  'forgotPassword.instructions':
      'Enter your email address. We\'ll send you a link to set a new '
      'password.',
  'forgotPassword.sendFailed': 'Couldn\'t be sent: {error}',
  'forgotPassword.send': 'Send link',
  'common.cancel': 'Cancel',
  'common.close': 'Close',

  'resetPassword.title': 'New password',
  'resetPassword.instructions': 'Please set a new password.',
  'resetPassword.newPassword': 'New password',
  'resetPassword.confirmPassword': 'Confirm password',
  'resetPassword.mismatch': 'Passwords don\'t match',
  'resetPassword.changeFailed': 'Change failed: {error}',
  'resetPassword.changed': 'Password changed.',
  'resetPassword.submit': 'Change password',

  'settings.title': 'Settings',
  'settings.help': 'Help',
  'settings.howItWorks': 'How SAMEPACE works',
  'settings.tutorialSubtitle': 'Watch a short tutorial',
  'settings.chats': 'Chats',
  'settings.autoArchiveDesc':
      'Automatically archive chats with no new message for 7 days.',
  'settings.autoArchive': 'Auto-archive',
  'settings.notifications': 'Notifications',
  'settings.notificationsDescSupported':
      'Get a browser notification for new messages and Sportbuddys while '
      'SAMEPACE is open in a tab.',
  'settings.notificationsDescUnsupported':
      'Your browser doesn\'t support notifications.',
  'settings.browserNotifications': 'Browser notifications',
  'settings.permissionDenied':
      'Permission not granted. You can change it in your browser settings.',
  'settings.design': 'Design',
  'settings.designDesc': 'Choose the look that suits you best.',
  'settings.language': 'Language',
  'settings.languageDesc': 'Which language should SAMEPACE be shown in?',

  'home.question': 'What do you want to do this week?',
  'home.tutorialTooltip': 'Tutorial',

  'nav.discover': 'Discover',
  'nav.plan': 'Plan',
  'nav.buddies': 'Buddies',
  'nav.chat': 'Chat',
  'nav.profile': 'Profile',
  'appbar.home': 'Home',
  'appbar.settings': 'Settings',
};
