import 'package:flutter/material.dart';

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

const _slides = [
  _TutorialSlide(
    icon: Icons.terrain,
    title: 'Willkommen bei SAMEPACE',
    description:
        'Finde Leute, die zur gleichen Zeit und im gleichen Tempo Sport '
        'machen möchten wie du — zum Laufen, Radfahren, Schwimmen, Wandern, '
        'Tennis und mehr.',
  ),
  _TutorialSlide(
    icon: Icons.calendar_today_outlined,
    title: 'Mein Sportplan',
    description:
        'Trag deine Sportzeiten ein — wiederkehrend jede Woche oder '
        'einmalig an einem bestimmten Tag. Pace, Level oder Distanz je nach '
        'Sportart.',
  ),
  _TutorialSlide(
    icon: Icons.people_outline,
    title: 'Matches',
    description:
        'Sobald jemand eine passende Sportzeit einträgt, seht ihr euch '
        'gegenseitig als Match — mit Pace, Level und ob schon ein Platz '
        'gebucht ist.',
  ),
  _TutorialSlide(
    icon: Icons.explore_outlined,
    title: 'Entdecken',
    description:
        'Stöbere nach Datum durch alle Sportzeiten in deiner Nähe und nach '
        'kuratierten Community-Events — filterbar nach Sportart und '
        'Uhrzeit.',
  ),
  _TutorialSlide(
    icon: Icons.chat_bubble_outline,
    title: 'Chat',
    description:
        'Sprich dich in der Gruppe ab, legt einen Treffpunkt auf der Karte '
        'fest und seht direkt, wo es losgeht.',
  ),
  _TutorialSlide(
    icon: Icons.person_outline,
    title: 'Profil',
    description:
        'Zeig deine Sportarten, dein Level, deine Interessen und Sprachen — '
        'so finden andere leichter heraus, ob ihr zusammenpasst.',
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      Navigator.of(context).pop();
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.showSkip && !isLast)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Überspringen'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  );
                },
              ),
            ),
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(isLast ? 'Los geht\'s' : 'Weiter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
