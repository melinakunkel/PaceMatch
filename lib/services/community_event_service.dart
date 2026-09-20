import '../models/community_event.dart';
import 'supabase_service.dart';

class CommunityEventService {
  final _client = SupabaseService.client;

  /// Curated events in [city] that fall on [date] — recurring ones on that
  /// weekday, or one-offs with a matching specific_date.
  Future<List<CommunityEvent>> getForCityAndDate({
    required String city,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('community_events')
        .select()
        .eq('city', city)
        .or('day_of_week.eq.${date.weekday},specific_date.eq.$dateStr')
        .order('start_time');
    return rows.map((m) => CommunityEvent.fromMap(m)).toList();
  }
}
