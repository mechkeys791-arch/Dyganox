import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class VehicleService {
  static Future<List<Map<String, dynamic>>> getMakes(String type) async {
    final uri = Uri.parse('${ApiConfig.vehicleEndpoint}/makes').replace(
      queryParameters: {'type': type},
    );
    final r = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body) as List<dynamic>?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  static Future<List<Map<String, dynamic>>> getModels(int makeId) async {
    final uri = Uri.parse('${ApiConfig.vehicleEndpoint}/models').replace(
      queryParameters: {'makeId': makeId.toString()},
    );
    final r = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body) as List<dynamic>?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  static Future<List<Map<String, dynamic>>> getMyVehicles(String email) async {
    if (email.isEmpty) return [];
    final uri = Uri.parse('${ApiConfig.vehicleEndpoint}/my').replace(
      queryParameters: {'email': email},
    );
    final r = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body) as List<dynamic>?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  static Future<Map<String, dynamic>?> createVehicle({
    required String userEmail,
    required String type,
    required int makeId,
    required int modelId,
    required String makeName,
    required String modelName,
    String? modelImageUrl,
    required String plateNumber,
    String? year,
    String? fuelType,
    bool isDefault = false,
  }) async {
    final body = {
      'userEmail': userEmail,
      'type': type,
      'makeId': makeId,
      'modelId': modelId,
      'makeName': makeName,
      'modelName': modelName,
      if (modelImageUrl != null && modelImageUrl.isNotEmpty) 'modelImageUrl': modelImageUrl,
      'plateNumber': plateNumber,
      if (year != null && year.isNotEmpty) 'year': year,
      if (fuelType != null && fuelType.isNotEmpty) 'fuelType': fuelType,
      'isDefault': isDefault,
    };
    final r = await http.post(
      Uri.parse('${ApiConfig.vehicleEndpoint}/my'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  static Future<Map<String, dynamic>?> updateVehicle(
    int id, {
    String? plateNumber,
    String? year,
    String? fuelType,
    String? modelImageUrl,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{};
    if (plateNumber != null) body['plateNumber'] = plateNumber;
    if (year != null) body['year'] = year;
    if (fuelType != null) body['fuelType'] = fuelType;
    if (modelImageUrl != null) body['modelImageUrl'] = modelImageUrl;
    if (isDefault != null) body['isDefault'] = isDefault;
    final r = await http.put(
      Uri.parse('${ApiConfig.vehicleEndpoint}/my/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  static Future<bool> deleteVehicle(int id) async {
    final r = await http.delete(Uri.parse('${ApiConfig.vehicleEndpoint}/my/$id'));
    return r.statusCode == 200 || r.statusCode == 204;
  }

}
