import 'sport_type.dart';

/// The Home screen's sport-grid customization: display order plus which
/// sports are hidden — persisted per account (see 0032_home_layout.sql) so
/// it's the same after logging in anywhere, not just on one device.
class HomeLayout {
  const HomeLayout({
    this.order = const [],
    this.hidden = const [],
    this.preferred = const [],
  });

  /// Sport names in the user's chosen order. May be incomplete (missing a
  /// sport added to the app since they last customized it) or empty
  /// (never customized) — always resolve through [resolve]/[fullOrder]
  /// rather than reading this directly.
  final List<String> order;

  /// Sport names the user turned off.
  final List<String> hidden;

  /// The user's own sports (from onboarding / profile) — not persisted as
  /// part of the layout. Until the user arranges the grid themselves, these
  /// come first.
  final List<SportType> preferred;

  /// Every selectable [SportType], in the user's order, with any sport
  /// missing from [order] (e.g. newly added ones) appended at the end. Never
  /// customized: the user's own sports ([preferred]) first.
  List<SportType> fullOrder() {
    final remaining = {for (final s in SportType.selectable) s.name: s};
    final ordered = <SportType>[];
    final names = order.isNotEmpty
        ? order
        : [for (final s in preferred) s.name];
    for (final name in names) {
      final sport = remaining.remove(name);
      if (sport != null) ordered.add(sport);
    }
    ordered.addAll(remaining.values);
    return ordered;
  }

  /// The sports to actually show on Home: [fullOrder] minus [hidden].
  List<SportType> resolve() =>
      fullOrder().where((s) => !hidden.contains(s.name)).toList();
}
