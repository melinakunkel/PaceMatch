import '../models/picked_location.dart';
import '../models/saved_location.dart';
import 'supabase_service.dart';

class SavedLocationService {
  final _client = SupabaseService.client;

  Future<List<SavedLocation>> getSavedLocations() async {
    final rows = await _client
        .from('saved_locations')
        .select()
        .eq('user_id', SupabaseService.currentUserId as String)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map((m) => SavedLocation.fromMap(m)).toList();
  }

  Future<void> saveLocation(PickedLocation location) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('saved_locations').insert({
      'user_id': SupabaseService.currentUserId,
      'name': location.name,
      'latitude': location.latitude,
      'longitude': location.longitude,
    });
  }

  Future<void> deleteSavedLocation(String id) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('saved_locations').delete().eq('id', id);
  }
}
