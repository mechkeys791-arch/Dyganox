# Service History Automatic Tracking - Usage Guide

## Overview
The `ServiceHistoryHelper` class provides automatic service tracking functionality that can be integrated into any service booking page.

## How to Use

### 1. Import the Helper
```dart
import 'service_history_helper.dart';
```

### 2. Add Service When Booking

When a user books a service, call the `addServiceToHistory` method:

```dart
// Example: When booking a car service
await ServiceHistoryHelper.addServiceToHistory(
  serviceName: 'Car Full Service',
  vehicleInfo: 'Honda City - MH 12 AB 1234',
  amount: '2500',
  notes: 'Oil change, brake check, general inspection',
  status: 'pending', // Options: 'pending', 'completed', 'cancelled'
);
```

### 3. Update Service Status

When a service is completed or status changes:

```dart
await ServiceHistoryHelper.updateServiceStatus(
  serviceName: 'Car Full Service',
  date: '15 Oct 2024',
  newStatus: 'completed',
  amount: '2500',
);
```

### 4. Integration Examples

#### Example 1: Car Service Page
```dart
// In car_service_page.dart
ElevatedButton(
  onPressed: () async {
    // Book the service
    // ... your booking logic ...
    
    // Automatically add to history
    await ServiceHistoryHelper.addServiceToHistory(
      serviceName: 'Car Full Service',
      vehicleInfo: selectedVehicle,
      status: 'pending',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Service booked successfully!')),
    );
  },
  child: Text('Book Service'),
)
```

#### Example 2: Towing Service Page
```dart
// In towing_service_page.dart
await ServiceHistoryHelper.addServiceToHistory(
  serviceName: 'Towing Service',
  vehicleInfo: '$vehicleName - $vehicleNumber',
  amount: '1500',
  notes: 'From: $pickupLocation\nTo: $dropLocation',
  status: 'pending',
);
```

#### Example 3: Battery Jump Start Page
```dart
// In battery_jump_page.dart
await ServiceHistoryHelper.addServiceToHistory(
  serviceName: 'Battery Jump Start',
  vehicleInfo: vehicleDetails,
  amount: '500',
  notes: 'Emergency service at $location',
  status: 'pending',
);
```

## Service Status Options

- **pending**: Service has been booked but not yet completed
- **completed**: Service has been successfully completed
- **cancelled**: Service was cancelled

## Benefits

1. **Automatic Tracking**: No manual entry needed by users
2. **Consistent Format**: All services are stored in the same format
3. **Easy to Use**: Simple API with clear parameters
4. **Persistent Storage**: Data is saved using SharedPreferences
5. **Real-time Updates**: Service history updates immediately

## Future Enhancements

Consider integrating this with:
- Backend API to sync across devices
- Push notifications when service status changes
- Service reminders based on history
- Analytics and reporting features

