import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Uploads damage photos/videos for mechanic requests. Returns a URL (S3 or local serve).
class RequestDamageUploadService {
  /// Upload a single file. [filePath] is the local path from ImagePicker.
  /// Returns the URL string or null on failure.
  static Future<String?> uploadFile(String filePath, String userEmail) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/request-damage-photo');
    final request = http.MultipartRequest('POST', uri);
    request.fields['email'] = userEmail;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) return null;
      final map = jsonDecode(response.body) as Map<String, dynamic>?;
      final url = map?['url']?.toString();
      if (url == null || url.isEmpty) return null;
      if (url.startsWith('http')) return url;
      return '${ApiConfig.baseUrl}$url';
    } catch (_) {
      return null;
    }
  }

  /// Upload multiple files and return list of URLs (skips failures).
  static Future<List<String>> uploadFiles(List<String> filePaths, String userEmail) async {
    final urls = <String>[];
    for (final path in filePaths) {
      if (path.startsWith('http')) {
        urls.add(path);
        continue;
      }
      final url = await uploadFile(path, userEmail);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
