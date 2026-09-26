import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/home_layout.dart';
import '../../models/sport_type.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../tutorial/tutorial_screen.dart';
import 'home_layout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profileService = ProfileService();
  List<SportType> _sports = SportType.selectable;

  /// "⚡ Heute spontan": a sport tap then creates a one-off for today
  /// instead of a weekly plan.
  bool _today = false;

  @override
  void initState() {
    super.initState();
    _maybeShowTutorial();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final layout = await _profileService.getHomeLayout(userId);
    if (mounted) setState(() => _sports = layout.resolve());
  }

  Future<void> _configureLayout() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final currentLayout = await _profileService.getHomeLayout(userId);
    if (!mounted) return;
    final result = await Navigator.of(context).push<HomeLayout>(
      MaterialPageRoute(
        builder: (_) => HomeLayoutScreen(initial: currentLayout),
      ),
    );
    if (result != null && mounted) {
      setState(() => _sports = result.resolve());
    }
  }

  // Checked against the account, not local browser storage: an in-app or
  // webview browser can wipe local storage between sessions, which used to
  // bring the tutorial back every login even after the user dismissed it.
  Future<void> _maybeShowTutorial() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final seen = await _profileService.getHasSeenTutorial(userId);
    if (seen || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TutorialScreen(showSkip: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: null,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terrain, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'SAMEPACE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.dashboard_customize_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: t('home.configureTooltip'),
                  onPressed: _configureLayout,
                ),
                IconButton(
                  icon: Icon(Icons.help_outline, color: AppColors.primary),
                  tooltip: t('home.tutorialTooltip'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TutorialScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('app.tagline'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Always one line: shrinks to fit narrow phones instead of
            // wrapping.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _today ? t('home.questionToday') : t('home.question'),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // One control, two halves — the active one is filled, so
            // "which mode am I in" is obvious at a glance.
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: Text(t('home.modePlan')),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: Text(t('home.modeToday')),
                  ),
                ],
                selected: {_today},
                onSelectionChanged: (v) => setState(() => _today = v.first),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: _sports
                    .map((sport) => _SportCard(sport: sport, today: _today))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({required this.sport, required this.today});

  final SportType sport;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/new-activity?sport=${sport.name}${today ? '&when=today' : ''}',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(sport.icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                sport.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
