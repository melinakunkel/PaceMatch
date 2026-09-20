import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A decorative network photo with a graceful gradient+icon fallback if the
/// image fails to load (offline, blocked host, ...) instead of a broken
/// image glyph.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.fallbackIcon = Icons.image_outlined,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final IconData fallbackIcon;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback(loading: true);
        },
        errorBuilder: (context, error, stackTrace) => _fallback(),
      ),
    );
  }

  Widget _fallback({bool loading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondaryLight,
            AppColors.secondary.withValues(alpha: 0.3),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            )
          : Icon(
              fallbackIcon,
              size: 36,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
    );
  }
}
