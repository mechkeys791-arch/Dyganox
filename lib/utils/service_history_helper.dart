import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ServiceHistoryHelper {
  // Add a service to history automatically
  static Future<void> addServiceToHistory({
    required String serviceName,
    required String vehicleInfo,
    String? amount,
    String? notes,
    String status = 'pending',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('service_history');
    
    List<Map<String, dynamic>> serviceHistory = [];
    if (historyJson != null) {
      serviceHistory = List<Map<String, dynamic>>.from(json.decode(historyJson));
    }

    // Get current date
    final now = DateTime.now();
    final date = '${now.day} ${_getMonthName(now.month)} ${now.year}';

    // Add new service to the beginning of the list
    serviceHistory.insert(0, {
      'name': serviceName,
      'date': date,
      'amount': amount ?? 'N/A',
      'vehicle': vehicleInfo,
      'status': status,
      'notes': notes ?? '',
    });

    // Save back to SharedPreferences
    await prefs.setString('service_history', json.encode(serviceHistory));
  }

  // Update service status (e.g., from pending to completed)
  static Future<void> updateServiceStatus({
    required String serviceName,
    required String date,
    required String newStatus,
    String? amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('service_history');
    
    if (historyJson != null) {
      List<Map<String, dynamic>> serviceHistory = 
          List<Map<String, dynamic>>.from(json.decode(historyJson));
      
      // Find and update the service
      for (var i = 0; i < serviceHistory.length; i++) {
        if (serviceHistory[i]['name'] == serviceName && 
            serviceHistory[i]['date'] == date) {
          serviceHistory[i]['status'] = newStatus;
          if (amount != null) {
            serviceHistory[i]['amount'] = amount;
          }
          break;
        }
      }
      
      // Save back
      await prefs.setString('service_history', json.encode(serviceHistory));
    }
  }

  // Get month name from number
  static String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // Get all service history
  static Future<List<Map<String, dynamic>>> getServiceHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('service_history');
    
    if (historyJson != null) {
      return List<Map<String, dynamic>>.from(json.decode(historyJson));
    }
    return [];
  }

  // Get count of services by status
  static Future<Map<String, int>> getServiceCounts() async {
    final history = await getServiceHistory();
    
    Map<String, int> counts = {
      'total': history.length,
      'completed': 0,
      'pending': 0,
      'cancelled': 0,
    };

    for (var service in history) {
      final status = service['status'].toString().toLowerCase();
      if (counts.containsKey(status)) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }

    return counts;
  }
}

