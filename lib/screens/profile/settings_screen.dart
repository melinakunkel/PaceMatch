import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Einstellungen'),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<AppThemeVariant>(
          valueListenable: ThemeController.variant,
          builder: (context, activeVariant, _) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Design',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Wähle den Look, der am besten zu dir passt.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...AppThemeVariant.values.map((variant) {
                  final selected = variant == activeVariant;
                  final palette = variant._previewPalette;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => ThemeController.setVariant(variant),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? palette.primary : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _PalettePreview(colors: palette),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(variant.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(variant.description,
                                      style:
                                          TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected ? palette.primary : AppColors.border,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.colors});
  final _PreviewColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _dot(colors.primary, 30),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _dot(colors.secondary, 26),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _PreviewColors {
  const _PreviewColors(this.primary, this.secondary);
  final Color primary;
  final Color secondary;
}

extension on AppThemeVariant {
  _PreviewColors get _previewPalette {
    switch (this) {
      case AppThemeVariant.standard:
        return const _PreviewColors(Color(0xFF1B4332), Color(0xFF40916C));
      case AppThemeVariant.girly:
        return const _PreviewColors(Color(0xFF9D2953), Color(0xFFE85D8A));
      case AppThemeVariant.sporty:
        return const _PreviewColors(Color(0xFF14181F), Color(0xFFFF6B35));
    }
  }
}
