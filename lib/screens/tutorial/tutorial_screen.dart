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

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _page = 0;
  bool _dontShowAgain = false;

  /// Drives the little running shoe's up/down bob so it looks like it's
  /// jogging in place while it also slides along the progress track.
  late final AnimationController _bounceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pageController.dispose();
    _bounceController.dispose();
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
          const SizedBox(width: 12),
          Expanded(child: _buildProgressTrack(slideCount)),
          const SizedBox(width: 12),
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

  /// A route the tutorial's little running shoe jogs along, from the left
  /// edge (slide 1) to the right edge (the last slide) — a playful stand-in
  /// for the old row of progress dots.
  Widget _buildProgressTrack(int slideCount) {
    final progress = slideCount <= 1 ? 1.0 : _page / (slideCount - 1);
    const shoeSize = 30.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final shoeLeft =
            (trackWidth - shoeSize).clamp(0.0, double.infinity) * progress;
        return SizedBox(
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 18,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: 0,
                top: 18,
                width: trackWidth * progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: shoeLeft,
                top: 0,
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) {
                    final bounce = Curves.easeInOut.transform(
                      _bounceController.value,
                    );
                    return Transform.translate(
                      offset: Offset(0, -4 * bounce),
                      child: Transform.rotate(
                        angle: (bounce - 0.5) * 0.12,
                        child: child,
                      ),
                    );
                  },
                  child: _RunningShoeIcon(
                    color: AppColors.secondary,
                    size: shoeSize,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small hand-drawn running-shoe silhouette, facing right — the direction
/// it jogs across the tutorial's progress track.
class _RunningShoeIcon extends StatelessWidget {
  const _RunningShoeIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.62),
      painter: _ShoePainter(color),
    );
  }
}

class _ShoePainter extends CustomPainter {
  _ShoePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 62;

    final body = Path()
      ..moveTo(8 * sx, 50 * sy)
      ..lineTo(84 * sx, 47 * sy)
      ..quadraticBezierTo(97 * sx, 45 * sy, 92 * sx, 34 * sy)
      ..quadraticBezierTo(89 * sx, 28 * sy, 78 * sx, 27 * sy)
      ..lineTo(48 * sx, 21 * sy)
      ..quadraticBezierTo(34 * sx, 13 * sy, 19 * sx, 11 * sy)
      ..quadraticBezierTo(8 * sx, 11 * sy, 5 * sx, 22 * sy)
      ..lineTo(4 * sx, 39 * sy)
      ..quadraticBezierTo(3 * sx, 47 * sy, 8 * sx, 50 * sy)
      ..close();
    canvas.drawPath(body, Paint()..color = color);

    final sole = Path()
      ..moveTo(6 * sx, 50 * sy)
      ..lineTo(85 * sx, 47 * sy)
      ..quadraticBezierTo(93 * sx, 46 * sy, 90 * sx, 54 * sy)
      ..quadraticBezierTo(88 * sx, 60 * sy, 76 * sx, 59 * sy)
      ..lineTo(12 * sx, 59 * sy)
      ..quadraticBezierTo(4 * sx, 58 * sy, 6 * sx, 50 * sy)
      ..close();
    canvas.drawPath(sole, Paint()..color = Colors.white);

    final lacePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.2 * ((sx + sy) / 2)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(28 * sx, 24 * sy),
      Offset(38 * sx, 34 * sy),
      lacePaint,
    );
    canvas.drawLine(
      Offset(38 * sx, 20 * sy),
      Offset(48 * sx, 30 * sy),
      lacePaint,
    );
    canvas.drawLine(
      Offset(48 * sx, 17 * sy),
      Offset(58 * sx, 27 * sy),
      lacePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ShoePainter oldDelegate) =>
      oldDelegate.color != color;
}
