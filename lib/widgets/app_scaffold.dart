import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom-nav scaffold for the 5 main tabs (Home, Plan, Matches,
/// Chat, Profil), matching the footer icons in the SAMEPACE mockup.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  final int currentIndex;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const _routes = ['/', '/plan', '/matches', '/chat', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          context.go(_routes[index]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined), label: 'Plan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline), label: 'Matches'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
