import 'package:flutter_test/flutter_test.dart';
import 'package:dyganox/services/phone_call_service.dart';

void main() {
  late PhoneCallService phoneService;

  setUp(() {
    phoneService = PhoneCallService();
  });

  group('Phone Number Formatting Tests', () {
    test('Format 10-digit number with country code', () {
      expect(
        phoneService.formatPhoneNumber('9876543210'),
        '+919876543210',
      );
    });

    test('Format number with spaces', () {
      expect(
        phoneService.formatPhoneNumber('987 654 3210'),
        '+919876543210',
      );
    });

    test('Format number with dashes', () {
      expect(
        phoneService.formatPhoneNumber('987-654-3210'),
        '+919876543210',
      );
    });

    test('Format number with parentheses', () {
      expect(
        phoneService.formatPhoneNumber('(987) 654-3210'),
        '+919876543210',
      );
    });

    test('Format international number', () {
      expect(
        phoneService.formatPhoneNumber('+91 9876543210'),
        '+919876543210',
      );
    });

    test('Format number starting with 0', () {
      expect(
        phoneService.formatPhoneNumber('09876543210'),
        '+919876543210',
      );
    });

    test('Format emergency number', () {
      expect(
        phoneService.formatPhoneNumber('108'),
        '108',
      );
    });

    test('Format toll-free number', () {
      final result = phoneService.formatPhoneNumber('1800-123-4567');
      expect(result, contains('1800'));
    });
  });

  group('Phone Number Validation Tests', () {
    test('Valid 10-digit number', () {
      expect(phoneService.isValidPhoneNumber('9876543210'), isTrue);
    });

    test('Valid international number', () {
      expect(phoneService.isValidPhoneNumber('+919876543210'), isTrue);
    });

    test('Valid emergency number', () {
      expect(phoneService.isValidPhoneNumber('108'), isTrue);
      expect(phoneService.isValidPhoneNumber('100'), isTrue);
      expect(phoneService.isValidPhoneNumber('101'), isTrue);
    });

    test('Invalid - too short', () {
      expect(phoneService.isValidPhoneNumber('12'), isFalse);
    });

    test('Invalid - too long', () {
      expect(phoneService.isValidPhoneNumber('12345678901234567'), isFalse);
    });

    test('Invalid - contains letters', () {
      expect(phoneService.isValidPhoneNumber('987abc3210'), isFalse);
    });

    test('Invalid - empty string', () {
      expect(phoneService.isValidPhoneNumber(''), isFalse);
    });

    test('Valid with formatting characters', () {
      expect(phoneService.isValidPhoneNumber('987-654-3210'), isTrue);
      expect(phoneService.isValidPhoneNumber('+91 9876543210'), isTrue);
    });
  });

  group('Phone Number Extraction Tests', () {
    test('Extract single phone number from text', () {
      const text = 'Call us at 9876543210 for support';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers, isNotEmpty);
      expect(numbers.first, '+919876543210');
    });

    test('Extract multiple phone numbers from text', () {
      const text = 'Emergency: 108, Support: 9876543210, Office: 1800-123-4567';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers.length, greaterThanOrEqualTo(2));
    });

    test('Extract international format number', () {
      const text = 'Contact +91 9876543210 for inquiries';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers, contains('+919876543210'));
    });

    test('Extract formatted numbers', () {
      const text = 'Call 987-654-3210 or (123) 456-7890';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers, isNotEmpty);
    });

    test('No phone numbers in text', () {
      const text = 'This text has no phone numbers';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers, isEmpty);
    });

    test('Extract emergency numbers', () {
      const text = 'Emergency services: Police 100, Ambulance 108';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers.length, greaterThanOrEqualTo(2));
    });
  });

  group('Emergency Contacts Tests', () {
    test('Emergency contacts are defined', () {
      expect(PhoneCallService.emergencyContacts, isNotEmpty);
    });

    test('Police emergency number exists', () {
      expect(PhoneCallService.emergencyContacts['police'], '100');
    });

    test('Ambulance emergency number exists', () {
      expect(PhoneCallService.emergencyContacts['ambulance'], '108');
    });

    test('Fire emergency number exists', () {
      expect(PhoneCallService.emergencyContacts['fire'], '101');
    });

    test('All emergency numbers are valid', () {
      PhoneCallService.emergencyContacts.forEach((key, value) {
        expect(
          phoneService.isValidPhoneNumber(value),
          isTrue,
          reason: 'Emergency contact $key has invalid number: $value',
        );
      });
    });
  });

  group('Support Contacts Tests', () {
    test('Support contacts are defined', () {
      expect(PhoneCallService.supportContacts, isNotEmpty);
    });

    test('Customer support number exists', () {
      expect(
        PhoneCallService.supportContacts['customer_support'],
        isNotNull,
      );
    });

    test('All support numbers are valid', () {
      PhoneCallService.supportContacts.forEach((key, value) {
        expect(
          phoneService.isValidPhoneNumber(value),
          isTrue,
          reason: 'Support contact $key has invalid number: $value',
        );
      });
    });
  });

  group('Edge Cases Tests', () {
    test('Handle null characters in number', () {
      expect(phoneService.formatPhoneNumber('98765\u000043210'), '+919876543210');
    });

    test('Handle very long input with valid number', () {
      const text = 'This is a very long text with lots of words and a phone number 9876543210 somewhere in it';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers, isNotEmpty);
    });

    test('Handle special characters', () {
      expect(
        phoneService.formatPhoneNumber('987@654#3210'),
        '+919876543210',
      );
    });

    test('Handle leading/trailing spaces', () {
      expect(
        phoneService.formatPhoneNumber('  9876543210  '),
        '+919876543210',
      );
    });

    test('Handle mixed format', () {
      expect(
        phoneService.formatPhoneNumber('+91 (987) 654-3210'),
        '+919876543210',
      );
    });
  });

  group('Singleton Pattern Tests', () {
    test('Service returns same instance', () {
      final instance1 = PhoneCallService();
      final instance2 = PhoneCallService();
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('Integration Tests', () {
    test('Format then validate number', () {
      const input = '987-654-3210';
      final formatted = phoneService.formatPhoneNumber(input);
      expect(phoneService.isValidPhoneNumber(formatted), isTrue);
    });

    test('Extract then format numbers', () {
      const text = 'Contact: 987-654-3210';
      final numbers = phoneService.extractPhoneNumbers(text);
      expect(numbers, isNotEmpty);
      
      for (var number in numbers) {
        expect(phoneService.isValidPhoneNumber(number), isTrue);
      }
    });

    test('Multiple operations on same number', () {
      const input = '(987) 654-3210';
      final formatted = phoneService.formatPhoneNumber(input);
      final isValid = phoneService.isValidPhoneNumber(formatted);
      final extracted = phoneService.extractPhoneNumbers('Number: $input');
      
      expect(formatted, '+919876543210');
      expect(isValid, isTrue);
      expect(extracted, contains(formatted));
    });
  });

  group('Performance Tests', () {
    test('Format large batch of numbers quickly', () {
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 1000; i++) {
        phoneService.formatPhoneNumber('9876543210');
      }
      
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Formatting 1000 numbers should take less than 1 second');
    });

    test('Extract from large text quickly', () {
      final largeText = List.generate(100, (i) => 
        'Contact person $i at 98765432${i.toString().padLeft(2, '0')}'
      ).join('. ');
      
      final stopwatch = Stopwatch()..start();
      final numbers = phoneService.extractPhoneNumbers(largeText);
      stopwatch.stop();
      
      expect(numbers, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Extracting from large text should be fast');
    });
  });
}

