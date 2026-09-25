import 'package:flutter/material.dart';

import '../../constants/app_info.dart';
import '../../l10n/strings.dart';
import 'legal_widgets.dart';

/// Datenschutzerklärung (DSGVO). Describes the data SAMEPACE actually
/// collects today; the [placeholder] entries (Verantwortlicher) must be
/// filled in with the real operator details before this app is published.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('privacy.title')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PlaceholderNotice(
              text:
                  'Noch nicht fertig: Die mit [ ] markierten Angaben werden '
                  'vor dem öffentlichen Start ergänzt.',
            ),
            LegalSection(
              heading: 'Verantwortlicher',
              lines: [
                AppInfo.operatorName,
                placeholder('Anschrift'),
                'E-Mail: ${AppInfo.contactEmail}',
              ],
            ),
            const LegalSection(
              heading: 'Welche Daten wir verarbeiten',
              lines: [
                'Profildaten: Vorname, Nachname, Alter, Geschlecht, Stadt, '
                    'Profilfoto, Kurzbeschreibung, Interessen und Sprachen.',
                'Trainingsdaten: Sportart, geplante Zeiten, Tempo/Level und '
                    'optionale Treffpunkte inkl. Standortkoordinaten.',
                'Kommunikationsdaten: Nachrichten in privaten Chats und '
                    'Gruppen-Chats zwischen Nutzer:innen.',
                'Sicherheitsdaten: Blockierungen, Meldungen sowie anonyme '
                    'Bewertungen nach Treffen (erschienen / Angaben haben '
                    'gestimmt), aus denen deine Zuverlässigkeits-Werte '
                    'berechnet werden. Wer dich bewertet hat, sieht '
                    'niemand.',
                'Kontodaten: E-Mail-Adresse und Anmeldedaten für die '
                    'Registrierung/Anmeldung.',
              ],
            ),
            const LegalSection(
              heading: 'Wofür wir diese Daten nutzen',
              lines: [
                'Um passende Trainingspartner:innen anhand von Zeitfenster, '
                    'Tempo und Sportart vorzuschlagen, Chats zu ermöglichen '
                    'und die App sicher zu betreiben (Blockieren, Melden, '
                    'Zuverlässigkeits-Werte).',
              ],
            ),
            const LegalSection(
              heading: 'Rechtsgrundlage',
              lines: [
                'Die Verarbeitung erfolgt zur Erfüllung des Vertrags mit '
                    'dir (Art. 6 Abs. 1 lit. b DSGVO), da diese Daten für '
                    'die Kernfunktion der App — das Matching — notwendig '
                    'sind.',
              ],
            ),
            LegalSection(
              heading: 'Hosting & Auftragsverarbeitung',
              lines: [
                'Alle Daten werden bei unserem Hosting-Partner Supabase '
                    'gespeichert und verarbeitet. Mit Supabase besteht bzw. '
                    'wird ein Auftragsverarbeitungsvertrag abgeschlossen.',
                'Serverstandort: EU (Irland), Region „West EU“ von '
                    'Supabase. Deine Daten werden also innerhalb der EU '
                    'gespeichert.',
              ],
            ),
            const LegalSection(
              heading: 'Weitere Dienste',
              lines: [
                'Die Web-App wird über GitHub Pages (GitHub Inc.) '
                    'ausgeliefert; dabei wird technisch deine IP-Adresse '
                    'verarbeitet.',
                'Karten und die Ortssuche kommen von OpenStreetMap: Beim '
                    'Anzeigen der Karte bzw. Suchen eines Orts werden deine '
                    'IP-Adresse und der Suchbegriff bzw. Kartenausschnitt '
                    'an OpenStreetMap übermittelt.',
                'Einige Bilder werden von Unsplash geladen; dabei wird '
                    'deine IP-Adresse an Unsplash übermittelt.',
                'Push-Benachrichtigungen (nur wenn du sie einschaltest): '
                    'Wir speichern dafür die Push-Adresse deines Geräts. Die '
                    'Benachrichtigung wird verschlüsselt über den Push-Dienst '
                    'deines Browsers bzw. Handys zugestellt (z. B. Google, '
                    'Apple oder Mozilla); diese Dienste können den Inhalt '
                    'nicht lesen. Beim Ausschalten oder Abmelden wird die '
                    'Adresse gelöscht.',
              ],
            ),
            const LegalSection(
              heading: 'Sichtbarkeit deiner Daten für andere Nutzer:innen',
              lines: [
                'Anderen Nutzer:innen wird aus Sicherheitsgründen nur dein '
                    'Vorname angezeigt, nie dein Nachname. Profilfoto, Alter, '
                    'Stadt, Interessen und Trainingsdaten sind für andere '
                    'sichtbar, soweit sie für das Matching notwendig sind.',
              ],
            ),
            const LegalSection(
              heading: 'Speicherdauer',
              lines: [
                'Deine Daten werden gespeichert, solange dein Konto '
                    'besteht. Nach einer Löschung deines Kontos werden '
                    'deine Daten gelöscht, soweit keine gesetzlichen '
                    'Aufbewahrungspflichten entgegenstehen.',
              ],
            ),
            const LegalSection(
              heading: 'Lokale Speicherung (Web-Version)',
              lines: [
                'Die Web-Version speichert lokal in deinem Browser '
                    'technisch notwendige Einstellungen wie deine gewählte '
                    'Sprache und dein Design. Es werden keine Tracking- '
                    'oder Werbe-Cookies eingesetzt.',
              ],
            ),
            const LegalSection(
              heading: 'Deine Rechte',
              lines: [
                'Du hast das Recht auf Auskunft, Berichtigung, Löschung und '
                    'Einschränkung der Verarbeitung deiner Daten sowie auf '
                    'Datenübertragbarkeit und Widerspruch. Zudem kannst du '
                    'dich bei einer Datenschutz-Aufsichtsbehörde '
                    'beschweren.',
              ],
            ),
            LegalSection(
              heading: 'Kontakt für Datenschutz-Anfragen',
              lines: [
                'Für Auskunfts-, Berichtigungs- oder Löschanfragen wende '
                    'dich an: ${AppInfo.contactEmail}',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
