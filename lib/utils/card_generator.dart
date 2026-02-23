import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CardGenerator {
  // BIN (Bank Identification Number) for virtual cards
  static const String _cardBin = '5234';

  /// Generate 16-digit card number from 12-digit account number
  /// Format: BIN (4 digits) + Account Number (12 digits) = 16 digits
  static String generateCardNumber(String accountNumber) {
    // Remove any spaces or non-digits
    final cleanAccount = accountNumber.replaceAll(RegExp(r'\D'), '');

    if (cleanAccount.length != 12) {
      throw ArgumentError('Account number must be 12 digits');
    }

    // Combine BIN + account number
    final cardNumber = _cardBin + cleanAccount;

    // Format with spaces: XXXX XXXX XXXX XXXX
    return '${cardNumber.substring(0, 4)} ${cardNumber.substring(4, 8)} ${cardNumber.substring(8, 12)} ${cardNumber.substring(12, 16)}';
  }

  /// Generate random CVV (3-digit)
  static String generateCVV() {
    final random = Random();
    final cvv = random.nextInt(900) + 100; // 100-999
    return cvv.toString();
  }

  /// Generate expiry date (3 years from now)
  static String generateExpiryDate() {
    final now = DateTime.now();
    final expiryDate = DateTime(now.year + 5, now.month);
    final month = expiryDate.month.toString().padLeft(2, '0');
    final year = expiryDate.year.toString().substring(2); // Last 2 digits
    return '$month/$year';
  }

  /// Initialize card data for user if not exists
  static Future<void> initializeCardForUser(String userId, String accountNumber, String userName) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final snapshot = await userDoc.get();
    final data = snapshot.data();

    // Check if card already exists
    if (data != null && data.containsKey('cardNumber') && data['cardNumber'] != null) {
      return; // Card already initialized
    }

    // Generate new card data
    final cardNumber = generateCardNumber(accountNumber);
    final cvv = generateCVV();
    final expiry = generateExpiryDate();

    // Update user document with card data
    await userDoc.update({
      'cardNumber': cardNumber,
      'cardCVV': cvv,
      'cardExpiry': expiry,
    });
  }
}
