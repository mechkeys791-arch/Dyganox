import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BackendTestPage extends StatefulWidget {
  const BackendTestPage({super.key});

  @override
  State<BackendTestPage> createState() => _BackendTestPageState();
}

class _BackendTestPageState extends State<BackendTestPage> {
  String _testResult = 'Click "Test Backend" to check connection';
  bool _isLoading = false;

  Future<void> _testBackend() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing backend connection...';
    });

    try {
      print("🧪 Testing backend connection...");
      
      // Test 1: Check if backend is running
      final response = await http.get(
        Uri.parse("http://localhost:8081/api/person"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      print("📡 Backend response: ${response.statusCode}");
      print("📡 Response body: ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          _testResult = "✅ Backend is running!\nStatus: ${response.statusCode}\nResponse: ${response.body}";
        });
      } else {
        setState(() {
          _testResult = "⚠️ Backend responded with status: ${response.statusCode}\nResponse: ${response.body}";
        });
      }
    } catch (e) {
      print("❌ Backend test failed: $e");
      setState(() {
        _testResult = "❌ Backend connection failed:\n$e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPostRequest() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing POST request...';
    });

    try {
      print("🧪 Testing POST request...");
      
      final testData = {
        'name': 'Test Provider',
        'phone': '1234567890',
        'address': 'Test Address',
        'chargerType': 'Type 2',
        'rate': '10.50',
        'availableHours': '24/7',
      };

      print("📦 Sending test data: ${jsonEncode(testData)}");

      final response = await http.post(
        Uri.parse("http://localhost:8081/api/person"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(testData),
      ).timeout(const Duration(seconds: 10));

      print("📡 POST response: ${response.statusCode}");
      print("📡 POST response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _testResult = "✅ POST request successful!\nStatus: ${response.statusCode}\nResponse: ${response.body}";
        });
      } else {
        setState(() {
          _testResult = "⚠️ POST request failed with status: ${response.statusCode}\nResponse: ${response.body}";
        });
      }
    } catch (e) {
      print("❌ POST test failed: $e");
      setState(() {
        _testResult = "❌ POST request failed:\n$e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Test'),
        backgroundColor: const Color(0xFF706DC7),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backend Connection Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testBackend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Backend (GET)', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testPostRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test POST Request', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Results:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResult,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

