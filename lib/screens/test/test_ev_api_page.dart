import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestEVAPIPage extends StatefulWidget {
  const TestEVAPIPage({super.key});

  @override
  State<TestEVAPIPage> createState() => _TestEVAPIPageState();
}

class _TestEVAPIPageState extends State<TestEVAPIPage> {
  String _log = '';
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _log += '\n${DateTime.now().toString().substring(11, 19)} - $message';
    });
    print(message); // Also print to console
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _log = '=== Testing Backend Connection ===';
    });

    try {
      _addLog('🔍 Testing: http://10.73.102.113:8081/api/evprovider');
      
      final response = await http.get(
        Uri.parse('http://10.73.102.113:8081/api/evprovider'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout - Backend not responding');
        },
      );

      _addLog('✅ Connected! Status: ${response.statusCode}');
      _addLog('📦 Response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addLog('📊 Found ${data.length} records in database');
      }
    } catch (e) {
      _addLog('❌ ERROR: $e');
      _addLog('⚠️ Make sure backend is running on port 8081!');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testPost() async {
    setState(() {
      _isLoading = true;
      _log = '=== Testing POST Request ===';
    });

    final testData = {
      'name': 'Test User ${DateTime.now().millisecond}',
      'phone': '9876543210',
      'address': 'Test Address, Bangalore',
      'chargerType': 'Type 2',
      'rate': '15.50',
      'availableHours': '24/7',
    };

    try {
      _addLog('📤 Sending POST to: http://10.73.102.113:8081/api/evprovider');
      _addLog('📦 Data: ${jsonEncode(testData)}');
      
      final response = await http.post(
        Uri.parse('http://10.73.102.113:8081/api/evprovider'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testData),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout - Backend not responding');
        },
      );

      _addLog('📡 Response Status: ${response.statusCode}');
      _addLog('📡 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _addLog('✅ SUCCESS! Data saved to database!');
        final savedData = jsonDecode(response.body);
        _addLog('💾 Saved with ID: ${savedData['id']}');
      } else {
        _addLog('❌ FAILED! Status: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ ERROR: $e');
      _addLog('⚠️ Make sure backend is running on port 8081!');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testFullFlow() async {
    setState(() {
      _isLoading = true;
      _log = '=== Testing Full Flow ===';
    });

    // Step 1: Check connection
    _addLog('STEP 1: Checking connection...');
    try {
      final pingResponse = await http.get(
        Uri.parse('http://10.73.102.113:8081/api/evprovider'),
      ).timeout(const Duration(seconds: 5));
      _addLog('✅ Backend is reachable (Status: ${pingResponse.statusCode})');
    } catch (e) {
      _addLog('❌ Backend NOT reachable: $e');
      setState(() => _isLoading = false);
      return;
    }

    // Step 2: Get initial count
    _addLog('\nSTEP 2: Getting current data count...');
    int initialCount = 0;
    try {
      final getResponse = await http.get(
        Uri.parse('http://10.73.102.113:8081/api/evprovider'),
      );
      final data = jsonDecode(getResponse.body);
      initialCount = data.length;
      _addLog('📊 Current records in database: $initialCount');
    } catch (e) {
      _addLog('❌ Error getting data: $e');
    }

    // Step 3: Post new data
    _addLog('\nSTEP 3: Posting new data...');
    final testData = {
      'name': 'Flutter Test ${DateTime.now().millisecond}',
      'phone': '9999999999',
      'address': 'Flutter Test Address',
      'chargerType': 'CCS',
      'rate': '20.00',
      'availableHours': '24/7',
    };

    int? newId;
    try {
      _addLog('📤 Sending: ${jsonEncode(testData)}');
      final postResponse = await http.post(
        Uri.parse('http://10.73.102.113:8081/api/evprovider'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testData),
      );
      
      _addLog('📡 POST Response: ${postResponse.statusCode}');
      
      if (postResponse.statusCode == 200 || postResponse.statusCode == 201) {
        final savedData = jsonDecode(postResponse.body);
        newId = savedData['id'];
        _addLog('✅ Data saved with ID: $newId');
      } else {
        _addLog('❌ POST failed: ${postResponse.body}');
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      _addLog('❌ POST error: $e');
      setState(() => _isLoading = false);
      return;
    }

    // Step 4: Verify data was saved
    _addLog('\nSTEP 4: Verifying data was saved...');
    await Future.delayed(const Duration(seconds: 1)); // Wait a bit
    
    try {
      final verifyResponse = await http.get(
        Uri.parse('http://10.73.102.113:8081/api/evprovider'),
      );
      final data = jsonDecode(verifyResponse.body);
      final newCount = data.length;
      
      _addLog('📊 Records now in database: $newCount');
      
      if (newCount > initialCount) {
        _addLog('✅ SUCCESS! Data is in database!');
        _addLog('📈 Increased from $initialCount to $newCount records');
        
        // Find our record
        final ourRecord = data.firstWhere(
          (record) => record['id'] == newId,
          orElse: () => null,
        );
        
        if (ourRecord != null) {
          _addLog('✅ Found our record: ${jsonEncode(ourRecord)}');
        }
      } else {
        _addLog('❌ PROBLEM! Data not found in database!');
        _addLog('⚠️ Count did not increase: Still $newCount records');
      }
    } catch (e) {
      _addLog('❌ Verification error: $e');
    }

    setState(() => _isLoading = false);
    _addLog('\n=== Test Complete ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Provider API Test'),
        backgroundColor: const Color(0xFF706DC7),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                const Text(
                  'Test EV Provider Backend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Endpoint: http://10.73.102.113:8081/api/evprovider',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testConnection,
                      icon: const Icon(Icons.wifi),
                      label: const Text('Test GET'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testPost,
                      icon: const Icon(Icons.send),
                      label: const Text('Test POST'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testFullFlow,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run Full Test (Recommended)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF706DC7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  _log.isEmpty ? 'Click a button to start testing...' : _log,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(width: 16),
                  Text(
                    'Testing... Check the log above',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

