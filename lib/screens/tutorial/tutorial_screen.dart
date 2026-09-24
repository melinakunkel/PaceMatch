import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class _TutorialSlide {
  const _TutorialSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// Not `const` so it always reflects the active language — still usable as
/// `_slides[i]`/`_slides.length` exactly like a plain list.
List<_TutorialSlide> get _slides => [
  _TutorialSlide(
    icon: Icons.terrain,
    title: t('tutorial.welcome.title'),
    description: t('tutorial.welcome.description'),
  ),
  _TutorialSlide(
    icon: Icons.calendar_today_outlined,
    title: t('tutorial.plan.title'),
    description: t('tutorial.plan.description'),
  ),
  _TutorialSlide(
    icon: Icons.people_outline,
    title: t('tutorial.buddies.title'),
    description: t('tutorial.buddies.description'),
  ),
  _TutorialSlide(
    icon: Icons.explore_outlined,
    title: t('tutorial.discover.title'),
    description: t('tutorial.discover.description'),
  ),
  _TutorialSlide(
    icon: Icons.chat_bubble_outline,
    title: t('tutorial.chat.title'),
    description: t('tutorial.chat.description'),
  ),
  _TutorialSlide(
    icon: Icons.person_outline,
    title: t('tutorial.profile.title'),
    description: t('tutorial.profile.description'),
  ),
];

/// A short swipeable "how it works" walkthrough, reachable from Settings,
/// Home and the login screen.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.showSkip = false});

  /// Whether to show a "Überspringen" button (used when shown automatically
  /// on first visit, rather than opened deliberately from a menu).
  final bool showSkip;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _dontShowAgain = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (widget.showSkip && _dontShowAgain) {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        await ProfileService().updateHasSeenTutorial(userId, true);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _dismiss();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final isLast = _page == slides.length - 1;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.6],
                  colors: [
                    AppColors.secondaryLight.withValues(alpha: 0.7),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            top: -90,
            right: _page.isEven ? -100 : null,
            left: _page.isEven ? null : -100,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(slides.length, isLast),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final slide = slides[i];
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          var page = _page.toDouble();
                          if (_pageController.hasClients &&
                              _pageController.page != null) {
                            page = _pageController.page!;
                          }
                          final delta = (page - i).clamp(-1.0, 1.0);
                          final opacity = (1 - delta.abs()).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, delta * 28),
                              child: child,
                            ),
                          );
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // A short/narrow viewport (small phone,
                            // split-screen browser window) can make a
                            // slide's icon+title+text taller than the
                            // space PageView gives it — scroll instead of
                            // overflowing, so the CTA button below always
                            // stays reachable.
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 380,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            t('tutorial.step', {
                                              'current': '${i + 1}',
                                              'total': '${slides.length}',
                                            }),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.1,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        Container(
                                          width: 108,
                                          height: 108,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.secondary,
                                                AppColors.primary,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.secondary
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 28,
                                                offset: const Offset(0, 14),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            slide.icon,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        Text(
                                          slide.title,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          slide.description,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppColors.textSecondary,
                                            height: 1.55,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // A Scaffold-managed bottom bar (rather than the last item in the
      // body's Column) so it's always pinned above the safe area
      // regardless of how tall a slide's content ends up being.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showSkip) ...[
                InkWell(
                  onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _dontShowAgain,
                          activeColor: AppColors.secondary,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: (v) =>
                              setState(() => _dontShowAgain = v ?? false),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          t('tutorial.dontShowAgain'),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isLast ? t('tutorial.done') : t('common.next')),
                      const SizedBox(width: 8),
                      Icon(
                        isLast
                            ? Icons.celebration_outlined
                            : Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int slideCount, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Material(
            color: AppColors.surface.withValues(alpha: 0.7),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close),
              iconSize: 20,
              onPressed: _dismiss,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: List.generate(slideCount, (i) {
                final active = i <= _page;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? AppColors.secondary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 68,
            child: widget.showSkip && !isLast
                ? TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      t('tutorial.skip'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
