import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings.dart';
import '../services/admin_notifier.dart';
import '../services/match_notifier.dart';
import '../services/unread_controller.dart';
import '../theme/app_theme.dart';
import 'circle_switcher.dart';
import 'notification_dot.dart';

/// Shared bottom-nav scaffold for the 5 main tabs (Entdecken, Plan, Matches,
/// Chat, Profil). Home isn't a tab — tapping the logo next to the title
/// reaches it from anywhere. Settings lives in the Profil tab instead of
/// its own persistent icon.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  /// Null for screens outside the 5-tab flow (Home): the bar still shows,
  /// for navigation, just with no tab highlighted.
  final int? currentIndex;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const _routes = [
    '/discover',
    '/plan',
    '/matches',
    '/chat',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              // The logo doubles as the Home shortcut, right next to the
              // title; screen-specific actions and the circle (public/
              // private area) switch sit in the standard actions row —
              // all in one line, since the title itself is small.
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.terrain),
                    tooltip: t('appbar.home'),
                    onPressed: () => context.go('/'),
                  ),
                  Expanded(
                    child: Text(title!, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              actions: [...?actions, const CircleSwitcherButton()],
            ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: _NavBar(currentIndex: currentIndex, routes: _routes),
    );
  }
}

/// Material 3 navigation bar: the active tab sits on a soft "pill" — the
/// look of current Android/iOS apps. Red dots for new buddies, unread chats
/// and (for admins) new reports.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.currentIndex, required this.routes});

  final int? currentIndex;
  final List<String> routes;

  Widget _dotted(ValueListenable<bool> flag, IconData icon) =>
      ValueListenableBuilder<bool>(
        valueListenable: flag,
        builder: (context, show, _) =>
            NotificationDot(show: show, child: Icon(icon)),
      );

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBar(
      // On Home (not one of the tabs) nothing is highlighted — see the
      // theme override below.
      selectedIndex: currentIndex ?? 0,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        context.go(routes[index]);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore),
          label: t('nav.discover'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.calendar_today_outlined),
          selectedIcon: const Icon(Icons.calendar_today),
          label: t('nav.plan'),
        ),
        NavigationDestination(
          icon: _dotted(MatchNotifier.hasNewMatch, Icons.people_outline),
          selectedIcon: _dotted(MatchNotifier.hasNewMatch, Icons.people),
          label: t('nav.buddies'),
        ),
        NavigationDestination(
          icon: _dotted(UnreadController.hasUnread, Icons.chat_bubble_outline),
          selectedIcon: _dotted(UnreadController.hasUnread, Icons.chat_bubble),
          label: t('nav.chat'),
        ),
        NavigationDestination(
          icon: _dotted(AdminNotifier.hasNew, Icons.person_outline),
          selectedIcon: _dotted(AdminNotifier.hasNew, Icons.person),
          label: t('nav.profile'),
        ),
      ],
    );
    final framed = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: bar,
    );
    if (currentIndex != null) return framed;
    return NavigationBarTheme(
      data: NavigationBarTheme.of(context).copyWith(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: AppColors.textSecondary),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
      child: framed,
    );
  }
}
