import 'package:flutter/material.dart';

import '../../constants/app_info.dart';
import '../../l10n/strings.dart';
import 'legal_widgets.dart';

/// Impressum (Anbieterkennzeichnung, §5 ECG / §25 MedienG). The address is
/// still a [placeholder] and must be filled in before this app is published
/// — see the warning banner at the top of the page.
class ImprintScreen extends StatelessWidget {
  const ImprintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('imprint.title')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PlaceholderNotice(
              text:
                  'Noch nicht fertig: Die Anschrift fehlt noch und wird vor '
                  'dem öffentlichen Start ergänzt.',
            ),
            LegalSection(
              heading: 'Angaben gemäß § 5 ECG / § 25 Mediengesetz',
              lines: [
                AppInfo.operatorName,
                placeholder('Straße und Hausnummer'),
                placeholder('PLZ und Ort'),
                placeholder('Land'),
              ],
            ),
            LegalSection(
              heading: 'Kontakt',
              lines: ['E-Mail: ${AppInfo.contactEmail}'],
            ),
            const LegalSection(
              heading: 'Unternehmensgegenstand',
              lines: [
                'Betrieb der mobilen Anwendung SAMEPACE zur '
                    'Vermittlung von Trainingspartner:innen im '
                    'Sportbereich.',
              ],
            ),
            LegalSection(
              heading: 'Verantwortlich für den Inhalt',
              lines: [AppInfo.operatorName],
            ),
            const LegalSection(
              heading: 'EU-Streitschlichtung',
              lines: [
                'Die Europäische Kommission stellt eine Plattform zur '
                    'Online-Streitbeilegung (OS) bereit. Wir sind nicht '
                    'verpflichtet und nicht bereit, an einem '
                    'Streitbeilegungsverfahren vor einer '
                    'Verbraucherschlichtungsstelle teilzunehmen.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
