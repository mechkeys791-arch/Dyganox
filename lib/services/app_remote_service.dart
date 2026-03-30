import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// GET home hero graphic config (transparent Lottie/GIF on red header). Returns { mediaType, mediaUrl, active }.
  static Future<Map<String, dynamic>?> getHomeHeroMediaConfig() async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/config/home-hero-media')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      }
    } catch (_) {}
    return null;
  }

  /// GET auth background video config for login/signup. Returns { videoUrl: String?, active: bool }.
  static Future<Map<String, dynamic>?> getAuthVideoConfig() async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/config/auth-video')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final map = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final url = map['videoUrl']?.toString()?.trim();
        if (url != null && url.isEmpty) map['videoUrl'] = null;
        return map;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Auth video config failed: $e');
    }
    return null;
  }

  /// GET app branding: appLogoUrl, splashMediaUrl, splashMediaType, welcomeTitle (e.g. "Welcome to ProMech").
  static Future<Map<String, dynamic>?> getAppBrandingConfig() async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/config/app-branding')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final map = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final logoUrl = map['appLogoUrl']?.toString()?.trim();
        final splashUrl = map['splashMediaUrl']?.toString()?.trim();
        final welcomePageUrl = map['welcomePageMediaUrl']?.toString()?.trim();
        if (logoUrl != null && logoUrl.isEmpty) map['appLogoUrl'] = null;
        if (splashUrl != null && splashUrl.isEmpty) map['splashMediaUrl'] = null;
        if (welcomePageUrl != null && welcomePageUrl.isEmpty) map['welcomePageMediaUrl'] = null;
        final welcomePageGifUrl = map['welcomePageGifUrl']?.toString()?.trim();
        if (welcomePageGifUrl != null && welcomePageGifUrl.isEmpty) map['welcomePageGifUrl'] = null;
        return map;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('App branding config failed: $e');
    }
    return null;
  }

  /// GET approved mechanic coordinates for "See nearest mechanic" map. Optional lat, lng, radiusKm filter. Returns { locations: [{ id: mechanicId, latitude, longitude }], markerIconUrl, userLocationMarkerIconUrl }.
  static Future<Map<String, dynamic>?> getNearestMechanicLocations({double? lat, double? lng, int radiusKm = 50}) async {
    try {
      final query = <String>['radiusKm=$radiusKm'];
      if (lat != null) query.add('lat=$lat');
      if (lng != null) query.add('lng=$lng');
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/config/nearest-mechanic-locations?${query.join('&')}')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Nearest mechanic locations failed: $e');
    }
    return null;
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
