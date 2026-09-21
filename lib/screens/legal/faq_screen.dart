import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';

/// Static Q&A list, reachable from Settings. Content lives in strings.dart
/// (faq.q1/a1 .. faq.q8/a8) alongside the rest of the app's translations.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _count = 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('faq.title')),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _count,
          itemBuilder: (context, i) {
            final n = i + 1;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(
                  t('faq.q$n'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('faq.a$n'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
