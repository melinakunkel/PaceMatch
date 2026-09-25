import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Puts the app's small red "something new" dot on the top right of
/// [child] when [show] is true.
class NotificationDot extends StatelessWidget {
  const NotificationDot({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (show)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1),
              ),
            ),
          ),
      ],
    );
  }
}
