import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/circle.dart';
import 'circle_service.dart';
import 'supabase_service.dart';

/// Holds the currently active "Kreis" context (null = Öffentlich) and
/// persists the choice, so it's remembered across app restarts and can be
/// switched at any time from anywhere in the app.
class CircleController {
  CircleController._();

  static const _prefsKey = 'active_circle_id';
  static final ValueNotifier<Circle?> active = ValueNotifier(null);

  static Future<void> loadSaved() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKey);
    if (savedId == null) return;
    try {
      final circles = await CircleService().getMyCircles(userId);
      final match = circles.where((c) => c.id == savedId);
      if (match.isNotEmpty) {
        active.value = match.first;
      } else {
        // No longer a member (left the circle elsewhere) — fall back to
        // Öffentlich instead of pointing at a circle that's gone.
        await prefs.remove(_prefsKey);
      }
    } catch (_) {
      // Offline or transient error — stays on whatever was already active.
    }
  }

  static Future<void> setActive(Circle? circle) async {
    active.value = circle;
    final prefs = await SharedPreferences.getInstance();
    if (circle == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, circle.id);
    }
  }

  /// Called on logout so the next account doesn't inherit this one's
  /// active circle.
  static void reset() {
    active.value = null;
  }
}
