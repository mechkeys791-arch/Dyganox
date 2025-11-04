# Phone Call Service Implementation Guide

## Overview
This guide explains the centralized phone call management system implemented across the Dyganox application. The `PhoneCallService` provides a unified, secure, and user-friendly way to handle all phone call operations.

## Features

### ✅ Key Capabilities
- **Unified Phone Call Handling**: Single service for all call operations
- **Phone Number Validation**: Automatic formatting and validation
- **Error Handling**: Comprehensive error management with user feedback
- **Confirmation Dialogs**: Optional user confirmation before calls
- **Emergency Call Support**: Quick access to emergency services
- **Multi-format Support**: Handles various phone number formats
- **Cross-platform**: Works on Android, iOS, and Web (where supported)

## Architecture

### Service Location
```
lib/services/phone_call_service.dart
```

### Singleton Pattern
The service uses a singleton pattern, ensuring consistent behavior across the app:
```dart
final PhoneCallService _phoneService = PhoneCallService();
```

## Phone Number Formats Supported

The service automatically handles these formats:
- International: `+91 9876543210`
- With dashes: `987-654-3210`
- With spaces: `987 654 3210`
- Standard 10-digit: `9876543210`
- Emergency numbers: `100`, `108`, `101`
- Toll-free: `1800-123-4567`

## Implementation Guide

### Step 1: Import the Service

```dart
import 'services/phone_call_service.dart';
```

### Step 2: Initialize in Your Widget

```dart
class YourPage extends StatefulWidget {
  // ... your code
}

class _YourPageState extends State<YourPage> {
  final PhoneCallService _phoneService = PhoneCallService();
  
  // ... rest of your code
}
```

### Step 3: Make Phone Calls

#### Basic Call with Confirmation
```dart
await _phoneService.makePhoneCall(
  '+91 9876543210',
  context: context,
  showConfirmation: true,
);
```

#### Emergency Call (No Confirmation)
```dart
await _phoneService.makePhoneCall(
  '108',
  context: context,
  showConfirmation: false,
);
```

#### Using Pre-defined Emergency Contacts
```dart
await _phoneService.makeEmergencyCall('ambulance', context);
// Options: 'police', 'ambulance', 'fire', 'disaster', 'women_helpline', 'child_helpline'
```

#### Using Support Contacts
```dart
await _phoneService.makeSupportCall('customer_support', context);
// Options: 'customer_support', 'emergency_roadside', 'technical_support'
```

## UI Components

### Phone Button Widget
```dart
_phoneService.buildPhoneButton(
  phoneNumber: '+91 9876543210',
  context: context,
  label: 'Call Mechanic',
  icon: Icons.phone_rounded,
  color: Color(0xFF706DC7),
  isEmergency: false,
)
```

### Phone Link Widget
```dart
_phoneService.buildPhoneLink(
  phoneNumber: '+91 9876543210',
  context: context,
  style: TextStyle(color: Colors.blue),
)
```

## Configuration

### Emergency Contacts
Located in `PhoneCallService.emergencyContacts`:
```dart
{
  'police': '100',
  'ambulance': '108',
  'fire': '101',
  'disaster': '1070',
  'women_helpline': '1091',
  'child_helpline': '1098',
  'roadside_assistance': '1800-123-4567',
}
```

### Support Contacts
Located in `PhoneCallService.supportContacts`:
```dart
{
  'customer_support': '+91 1800 123 4567',
  'emergency_roadside': '+91 9876543210',
  'technical_support': '+91 9876543211',
}
```

### Modifying Contact Numbers

To add or update contact numbers:

1. Open `lib/services/phone_call_service.dart`
2. Locate the appropriate constant map (`emergencyContacts` or `supportContacts`)
3. Add or modify entries:
```dart
static const Map<String, String> supportContacts = {
  'customer_support': '+91 1800 123 4567',
  'new_support_line': '+91 9999999999',  // Add new entry
};
```

## Updated Pages

The following pages have been updated to use the centralized service:

### ✅ Implemented
1. **Emergency Assistance Page** (`lib/emergency_assistance_page.dart`)
   - All mechanic call buttons
   - Emergency contact calls

2. **Mechanic Finder Page** (`lib/screens/mechanic/mechanic_finder_page.dart`)
   - Call mechanic buttons
   - Quick call actions

### 📋 Recommended for Update
3. **Tyre Care Page** (`lib/screens/services/tyre_care_page.dart`)
4. **Battery Jump Page** (`lib/screens/services/battery_jump_page.dart`)
5. **Night Service Page** (`lib/screens/services/night_service_page.dart`)
6. **All other service pages with call functionality**

## Migration Example

### Before (Old Implementation)
```dart
void _makePhoneCall(String phoneNumber) async {
  final Uri url = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    // Show error
  }
}
```

### After (New Implementation)
```dart
final PhoneCallService _phoneService = PhoneCallService();

void _makePhoneCall(String phoneNumber) async {
  await _phoneService.makePhoneCall(
    phoneNumber,
    context: context,
    showConfirmation: true,
  );
}
```

## Utility Methods

### Format Phone Number
```dart
String formatted = _phoneService.formatPhoneNumber('9876543210');
// Returns: '+919876543210'
```

### Validate Phone Number
```dart
bool isValid = _phoneService.isValidPhoneNumber('+91 9876543210');
// Returns: true or false
```

### Extract Phone Numbers from Text
```dart
List<String> numbers = _phoneService.extractPhoneNumbers(
  'Call us at +91 9876543210 or 1800-123-4567'
);
// Returns: ['+919876543210', '+911800123567']
```

## Testing

### Manual Testing Checklist

#### On Android/iOS Device:
- [ ] Test calling with 10-digit number
- [ ] Test calling with country code
- [ ] Test calling with formatted number (dashes/spaces)
- [ ] Test emergency numbers (100, 108, 101)
- [ ] Test confirmation dialog appears
- [ ] Test cancel in confirmation dialog
- [ ] Test proceed in confirmation dialog
- [ ] Test invalid number handling
- [ ] Test error messages display correctly

#### On Web Browser:
- [ ] Test that appropriate error message shows (if tel: not supported)
- [ ] Verify graceful degradation

### Unit Test Example
```dart
test('Phone number formatting', () {
  final service = PhoneCallService();
  expect(service.formatPhoneNumber('9876543210'), '+919876543210');
  expect(service.formatPhoneNumber('+91 987-654-3210'), '+919876543210');
});

test('Phone number validation', () {
  final service = PhoneCallService();
  expect(service.isValidPhoneNumber('9876543210'), true);
  expect(service.isValidPhoneNumber('123'), false);
  expect(service.isValidPhoneNumber('invalid'), false);
});
```

## Error Handling

The service handles these error scenarios:

1. **Invalid Phone Number**: Shows user-friendly error message
2. **Device Cannot Make Calls**: Shows appropriate message for web/desktop
3. **Permission Denied**: Handles OS-level permission denials
4. **Network Issues**: Graceful handling with error feedback

## Security Considerations

### Privacy
- ✅ No phone numbers are stored or logged
- ✅ All calls are initiated directly by the OS
- ✅ User confirmation required for non-emergency calls
- ✅ No external API calls for phone operations

### Best Practices
1. Always provide user confirmation for non-emergency calls
2. Format and validate numbers before calling
3. Handle errors gracefully with user feedback
4. Test across multiple devices and platforms

## Troubleshooting

### Common Issues

#### Issue: Calls not working on emulator
**Solution**: Use a physical device. Emulators may not support tel: URLs.

#### Issue: Confirmation dialog not appearing
**Solution**: Ensure `context` is passed and `showConfirmation: true`.

#### Issue: Invalid number error
**Solution**: Check number format. Service supports formats listed above.

#### Issue: Red underline in IDE on url_launcher
**Solution**: Ensure `url_launcher` is in `pubspec.yaml`:
```yaml
dependencies:
  url_launcher: ^6.2.0
```

## Performance

- **Lightweight**: Service is a singleton, minimal memory overhead
- **Fast**: Direct OS integration, no network delays
- **Efficient**: Lazy initialization, only created when needed

## Future Enhancements

Possible future additions:
- [ ] SMS sending capability
- [ ] WhatsApp integration
- [ ] Call history tracking
- [ ] Analytics integration
- [ ] International number support expansion
- [ ] VoIP calling options

## Support

For issues or questions:
1. Check this documentation
2. Review the source code comments in `phone_call_service.dart`
3. Test with different phone number formats
4. Verify device capabilities

## Version History

### v1.0.0 (Current)
- Initial implementation
- Basic call functionality
- Emergency and support contacts
- Phone number validation and formatting
- UI components (buttons, links)
- Error handling and user feedback

---

## Quick Reference

### Most Common Use Case
```dart
// Import
import 'services/phone_call_service.dart';

// Initialize
final PhoneCallService _phoneService = PhoneCallService();

// Use
await _phoneService.makePhoneCall(
  phoneNumber,
  context: context,
  showConfirmation: true,
);
```

That's it! The service handles everything else automatically.

