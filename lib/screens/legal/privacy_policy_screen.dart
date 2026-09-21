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
                  'Vorlage: Die mit [ ] markierten Angaben sind Platzhalter. '
                  'Vor dem öffentlichen Start sollten die echten Angaben '
                  'eingetragen und der Text idealerweise rechtlich geprüft '
                  'werden.',
            ),
            LegalSection(
              heading: 'Verantwortlicher',
              lines: [
                placeholder('Name der verantwortlichen Person/Firma'),
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
                'Kommunikationsdaten: Nachrichten in den Gruppen-Chats '
                    'zwischen gematchten Nutzer:innen.',
                'Sicherheitsdaten: Blockierungen, Meldungen und der aus '
                    'Check-ins berechnete Zuverlässigkeits-Score.',
                'Kontodaten: E-Mail-Adresse und Anmeldedaten für die '
                    'Registrierung/Anmeldung.',
              ],
            ),
            const LegalSection(
              heading: 'Wofür wir diese Daten nutzen',
              lines: [
                'Um passende Trainingspartner:innen anhand von Zeitfenster, '
                    'Tempo und Sportart vorzuschlagen, Gruppen-Chats zu '
                    'ermöglichen und die App sicher zu betreiben (Blockieren, '
                    'Melden, Zuverlässigkeits-Score).',
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
                placeholder('Serverstandort/Region von Supabase ergänzen'),
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
