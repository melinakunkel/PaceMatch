import 'sport_type.dart';

/// The Home screen's sport-grid customization: display order plus which
/// sports are hidden — persisted per account (see 0032_home_layout.sql) so
/// it's the same after logging in anywhere, not just on one device.
class HomeLayout {
  const HomeLayout({this.order = const [], this.hidden = const []});

  /// Sport names in the user's chosen order. May be incomplete (missing a
  /// sport added to the app since they last customized it) or empty
  /// (never customized) — always resolve through [resolve]/[fullOrder]
  /// rather than reading this directly.
  final List<String> order;

  /// Sport names the user turned off.
  final List<String> hidden;

  /// Every [SportType], in the user's order, with any sport missing from
  /// [order] appended at the end.
  List<SportType> fullOrder() {
    final remaining = {for (final s in SportType.values) s.name: s};
    final ordered = <SportType>[];
    for (final name in order) {
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
