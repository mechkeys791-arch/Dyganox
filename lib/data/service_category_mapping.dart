/// Maps service display names to backend problem category IDs for mechanic filtering.
/// Used by: mechanic registration, mechanic dashboard, car/bike service pages.
class ServiceCategoryMapping {
  /// Display name -> problemCategory ID for by-category API
  static const Map<String, String> serviceToCategory = {
    'Towing': 'towing_service',
    'Battery Jump': 'battery_jump',
    'Battery': 'battery_jump',
    'Tyre Care': 'tyre_puncture',
    'Brake Service': 'brake_issue',
    'Headlight Repair': 'headlight_repair',
    'Oil Change': 'oil_change',
    'Windshield': 'windshield',
    'Body Works': 'body_works',
    'Wheel Alignment': 'wheel_alignment',
    'Suspension': 'suspension',
    'General Repair': 'general_checkup',
    'Minor Repair': 'general_checkup',
    'Engine Service': 'engine_repair',
    'Electrical Works': 'electrical',
    'AC Repair': 'ac_issue',
    'Emergency': 'general_checkup',
    'Fuel Refill': 'general_checkup',
    'EV Charging': 'general_checkup',
    'Car Service': 'general_checkup',
    'Bike Service': 'general_checkup',
    'Tire Service': 'tyre_puncture',
    'Battery Service': 'battery_jump',
  };

  /// Get category ID for a service display name. Returns null if not found.
  static String? getCategoryId(String displayName) {
    return serviceToCategory[displayName] ?? serviceToCategory[displayName.trim()];
  }

  /// Convert list of display names to comma-separated category IDs for backend.
  static String toServiceCategories(List<String> displayNames) {
    final ids = <String>{};
    for (final name in displayNames) {
      final id = getCategoryId(name);
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return 'general_checkup';
    return ids.join(',');
  }
}
