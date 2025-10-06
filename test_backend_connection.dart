import 'dart:convert';
import 'dart:io';

void main() async {
  print("🧪 Testing backend connection...");
  
  final testData = {
    'name': 'Test User',
    'phone': '1234567890',
    'address': 'Test Address',
    'chargerType': 'Type 2',
    'rate': '15.50',
    'availableHours': '9AM-10AM',
  };
  
  try {
    print("📤 Sending test data: ${jsonEncode(testData)}");
    
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse("http://localhost:8081/api/person"));
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode(testData));
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    print("📡 Response Status: ${response.statusCode}");
    print("📡 Response Body: $responseBody");
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Backend is working correctly!");
    } else {
      print("❌ Backend returned error: ${response.statusCode}");
    }
    
    client.close();
  } catch (e) {
    print("💥 Error connecting to backend: $e");
  }
}
