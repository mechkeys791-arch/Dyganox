import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AppRemoteService {
  /// GET active marketing poster for location. Pass city/state and optionally lat/lng (for area circle). Returns null if none or error – app then shows homepage.
  static Future<Map<String, dynamic>?> getActivePoster({String? city, String? state, double? lat, double? lng}) async {
    try {
      final query = <String>[];
      if (city != null && city.trim().isNotEmpty) query.add('city=${Uri.encodeComponent(city.trim())}');
      if (state != null && state.trim().isNotEmpty) query.add('state=${Uri.encodeComponent(state.trim())}');
      if (lat != null) query.add('lat=$lat');
      if (lng != null) query.add('lng=$lng');
      final qs = query.isEmpty ? '' : '?${query.join('&')}';
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/poster/active$qs')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      }
    } catch (_) {}
    return null;
  }

  /// GET section posters (e.g. below "Our Services"). section=BELOW_SERVICES.
  static Future<List<Map<String, dynamic>>> getSectionPosters({String section = 'BELOW_SERVICES'}) async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/section-posters?section=${Uri.encodeComponent(section)}')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Version check. currentVersion e.g. 1.0.0. Returns map with updateAvailable, latestVersion, minRequiredVersion, updateTitle, updateMessage.
  static Future<Map<String, dynamic>?> checkVersion(String currentVersion) async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/version-check?currentVersion=${Uri.encodeComponent(currentVersion)}')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      }
    } catch (_) {}
    return null;
  }
}
