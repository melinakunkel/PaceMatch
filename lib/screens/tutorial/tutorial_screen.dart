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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _dismiss),
        actions: [
          if (widget.showSkip && !isLast)
            TextButton(onPressed: _dismiss, child: Text(t('tutorial.skip'))),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  // A short/narrow viewport (small phone, split-screen
                  // browser window) can make a slide's icon+title+text
                  // taller than the space PageView gives it — scroll
                  // instead of overflowing, so the Weiter button below
                  // always stays reachable.
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    slide.icon,
                                    size: 56,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  slide.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // A Scaffold-managed bottom bar (rather than the last item in the
      // body's Column) so it's always pinned above the safe area
      // regardless of how tall a slide's content ends up being.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppColors.secondary : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              if (widget.showSkip) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _dontShowAgain,
                          onChanged: (v) =>
                              setState(() => _dontShowAgain = v ?? false),
                        ),
                        Text(t('tutorial.dontShowAgain')),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? t('tutorial.done') : t('common.next')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
