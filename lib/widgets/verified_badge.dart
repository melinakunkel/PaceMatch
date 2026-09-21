import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Small "verified profile" checkmark. Purely a UI placeholder for now —
/// see ProfileScreen for the (also placeholder) "Profil verifizieren" flow.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: t('verifiedBadge.tooltip'),
      child: Icon(Icons.verified, size: size, color: AppColors.secondary),
    );
  }
}
