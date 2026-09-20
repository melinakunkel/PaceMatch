import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/sport_type.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                SizedBox(width: 8),
                Text(
                  'SAMEPACE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Was möchtest du diese Woche machen?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: SportType.values
                    .map((sport) => _SportCard(sport: sport))
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
  const _SportCard({required this.sport});

  final SportType sport;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/new-activity?sport=${sport.name}'),
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
            Text(
              sport.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
