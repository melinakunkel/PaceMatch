import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/profile/settings_screen.dart';
import '../services/unread_controller.dart';
import '../theme/app_theme.dart';

/// Shared bottom-nav scaffold for the 5 main tabs (Entdecken, Plan, Matches,
/// Chat, Profil). Home and Settings aren't tabs — they're reached via the
/// persistent icons every screen's app bar gets, top right.
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
              title: Text(title!),
              actions: [
                ...?actions,
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  tooltip: 'Home',
                  onPressed: () => context.go('/'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Einstellungen',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: Theme(
        // On Home, currentIndex is null (it isn't one of the 5 tabs) — still
        // show the bar so navigation stays reachable, just with nothing
        // highlighted, by making the "selected" and "unselected" colors match.
        data: currentIndex == null
            ? Theme.of(context).copyWith(
                bottomNavigationBarTheme: Theme.of(context)
                    .bottomNavigationBarTheme
                    .copyWith(selectedItemColor: AppColors.textSecondary),
              )
            : Theme.of(context),
        child: BottomNavigationBar(
          currentIndex: currentIndex ?? 0,
          onTap: (index) {
            if (index == currentIndex) return;
            context.go(_routes[index]);
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'Entdecken',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              label: 'Plan',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<bool>(
                valueListenable: UnreadController.hasUnread,
                builder: (context, unread, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      if (unread)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
