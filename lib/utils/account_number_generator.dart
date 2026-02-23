import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountNumberGenerator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random();

  /// Generates a unique 12-digit account number
  /// Format: XXXXXXXXXXXX (stored without dashes)
  /// Returns: "123456789012"
  static Future<String> generate() async {
    String accountNumber;
    bool isUnique = false;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      // Generate 12 random digits
      accountNumber = _generateRandomNumber();

      // Check if it already exists in Firestore
      isUnique = await _checkUniqueness(accountNumber);
      attempts++;

      if (attempts >= maxAttempts && !isUnique) {
        throw Exception('Failed to generate unique account number after $maxAttempts attempts');
      }
    } while (!isUnique);

    return accountNumber;
  }

  /// Generates a random 12-digit number as string
  static String _generateRandomNumber() {
    String number = '';
    for (int i = 0; i < 12; i++) {
      number += _random.nextInt(10).toString();
    }
    return number;
  }

  /// Checks if account number already exists in Firestore
  static Future<bool> _checkUniqueness(String accountNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('account_number', isEqualTo: accountNumber)
          .limit(1)
          .get();

      // If no documents found, the number is unique
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      // If error occurs during check, assume not unique for safety
      return false;
    }
  }

  /// Formats account number for display
  /// Input: "123456789012"
  /// Output: "1234-5678-9012"
  static String format(String accountNumber) {
    if (accountNumber.length != 12) {
      return accountNumber;
    }

    return '${accountNumber.substring(0, 4)}-'
        '${accountNumber.substring(4, 8)}-'
        '${accountNumber.substring(8, 12)}';
  }

  /// Removes formatting from account number
  /// Input: "1234-5678-9012" or "1234 5678 9012"
  /// Output: "123456789012"
  static String unformat(String formattedNumber) {
    return formattedNumber.replaceAll(RegExp(r'[\s\-]'), '');
  }

  /// Validates account number format
  /// Checks if it's exactly 12 digits (after removing formatting)
  static bool isValid(String accountNumber) {
    final unformatted = unformat(accountNumber);

    // Check if exactly 12 characters
    if (unformatted.length != 12) {
      return false;
    }

    // Check if all characters are digits
    return RegExp(r'^\d{12}$').hasMatch(unformatted);
  }

  /// Formats account number as user types (for TextField)
  /// Automatically adds dashes after 4th and 8th digit
  static String formatAsTyping(String input) {
    // Remove any existing dashes or spaces
    final cleaned = unformat(input);

    // Limit to 12 digits
    final truncated = cleaned.length > 12 ? cleaned.substring(0, 12) : cleaned;

    // Add dashes at appropriate positions
    String formatted = '';
    for (int i = 0; i < truncated.length; i++) {
      if (i == 4 || i == 8) {
        formatted += '-';
      }
      formatted += truncated[i];
    }

    return formatted;
  }
}
