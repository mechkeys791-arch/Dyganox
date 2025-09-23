import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestConnectionPage extends StatefulWidget {
  const TestConnectionPage({super.key});

  @override
  State<TestConnectionPage> createState() => _TestConnectionPageState();
}

class _TestConnectionPageState extends State<TestConnectionPage> {
  String _status = 'Ready to test';
  String _response = '';

  Future<void> _testConnection() async {
    setState(() {
      _status = 'Testing connection...';
      _response = '';
    });

    try {
      // Test GET request
      final getResponse = await http.get(
        Uri.parse("http://192.168.12.87:8081/api/person"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _status = 'GET request successful!';
        _response = 'Status: ${getResponse.statusCode}\nResponse: ${getResponse.body}';
      });

      // Test POST request
      final testData = {
        "name": "Mobile Test User",
        "phone": "9876543210",
        "address": "Mobile Test Address",
        "chargerType": "Type 2",
        "rate": "5.0",
        "availableHours": "9AM-10AM"
      };

      final postResponse = await http.post(
        Uri.parse("http://192.168.12.87:8081/api/person"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(testData),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _status = 'Both GET and POST successful!';
        _response += '\n\nPOST Status: ${postResponse.statusCode}\nPOST Response: ${postResponse.body}';
      });

    } catch (e) {
      setState(() {
        _status = 'Connection failed!';
        _response = 'Error: $e';
      });
    }
  }

  Future<void> _testPythonServer() async {
    setState(() {
      _status = 'Testing Python server...';
      _response = '';
    });

    try {
      // Test GET request to Python server
      final getResponse = await http.get(
        Uri.parse("http://192.168.12.87:8082/api/person"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _status = 'Python server GET successful!';
        _response = 'Status: ${getResponse.statusCode}\nResponse: ${getResponse.body}';
      });

      // Test POST request to Python server
      final testData = {
        "name": "Mobile Test User",
        "phone": "9876543210",
        "address": "Mobile Test Address",
        "chargerType": "Type 2",
        "rate": "5.0",
        "availableHours": "9AM-10AM"
      };

      final postResponse = await http.post(
        Uri.parse("http://192.168.12.87:8082/api/person"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(testData),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _status = 'Python server both requests successful!';
        _response += '\n\nPOST Status: ${postResponse.statusCode}\nPOST Response: ${postResponse.body}';
      });

    } catch (e) {
      setState(() {
        _status = 'Python server connection failed!';
        _response = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connection Test', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF706DC7),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Test Network Connection',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Status: $_status',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _status.contains('successful') ? Colors.green : 
                       _status.contains('failed') ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF706DC7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Test Spring Boot Backend (Port 8081)',
                style: GoogleFonts.outfit(fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _testPythonServer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Test Python Server (Port 8082)',
                style: GoogleFonts.outfit(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _response.isEmpty ? 'No response yet' : _response,
                    style: GoogleFonts.robotoMono(fontSize: 12),
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
