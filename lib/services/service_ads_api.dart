import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Public API: promotional strips (Night Service, etc.).
class ServiceAdsApi {
  ServiceAdsApi._();

  static String _normalizeMediaKey(String? raw) {
    if (raw == null) return '';
    var s = raw.trim().toLowerCase();
    if (s.startsWith('http://')) s = 'https://${s.substring(7)}';
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    return s;
  }

  static int _sortOrder(Map<String, dynamic> a) {
    final v = a['sortOrder'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _compareAds(Map<String, dynamic> a, Map<String, dynamic> b) {
    final sa = (a['source'] ?? '').toString().toUpperCase();
    final sb = (b['source'] ?? '').toString().toUpperCase();
    final pa = sa == 'PLATFORM' ? 0 : 1;
    final pb = sb == 'PLATFORM' ? 0 : 1;
    if (pa != pb) return pa.compareTo(pb);
    final oa = _sortOrder(a);
    final ob = _sortOrder(b);
    if (oa != ob) return oa.compareTo(ob);
    final ida = (a['id'] as num?)?.toInt() ?? 0;
    final idb = (b['id'] as num?)?.toInt() ?? 0;
    return ida.compareTo(idb);
  }

  static Future<List<Map<String, dynamic>>> fetch({
    String placement = 'NIGHT_SERVICE',
    double? lat,
    double? lng,
  }) async {
    final q = <String, String>{'placement': placement};
    if (lat != null && lng != null) {
      q['lat'] = lat.toString();
      q['lng'] = lng.toString();
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/service-ads').replace(queryParameters: q);
    try {
      final r = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Multiple placements: **one row per unique creative** (same [mediaUrl] only once).
  /// Order: first placement in [placements] wins for tie-break, then **PLATFORM** before MECHANIC, then sortOrder.
  static Future<List<Map<String, dynamic>>> fetchMerged(
    List<String> placements, {
    double? lat,
    double? lng,
  }) async {
    final lists = await Future.wait(
      placements.map((p) => fetch(placement: p, lat: lat, lng: lng)),
    );
    final byUrl = <String, Map<String, dynamic>>{};
    for (var pi = 0; pi < lists.length; pi++) {
      for (final a in lists[pi]) {
        final url = a['mediaUrl']?.toString() ?? '';
        final key = _normalizeMediaKey(url);
        if (key.isEmpty) continue;
        final copy = Map<String, dynamic>.from(a);
        copy['_placementPriority'] = pi;
        final existing = byUrl[key];
        if (existing == null) {
          byUrl[key] = copy;
        } else {
          final exPlat = (existing['source'] ?? '').toString().toUpperCase() == 'PLATFORM';
          final nwPlat = (copy['source'] ?? '').toString().toUpperCase() == 'PLATFORM';
          if (nwPlat && !exPlat) {
            byUrl[key] = copy;
          }
        }
      }
    }
    final out = byUrl.values.toList();
    out.sort((a, b) {
      final c = _compareAds(a, b);
      if (c != 0) return c;
      final pa = a['_placementPriority'] as int? ?? 99;
      final pb = b['_placementPriority'] as int? ?? 99;
      return pa.compareTo(pb);
    });
    for (final m in out) {
      m.remove('_placementPriority');
    }
    return out;
  }
}
