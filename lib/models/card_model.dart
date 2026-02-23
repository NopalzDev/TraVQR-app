class VirtualCard {
  final String cardNumber;      // 16-digit: "5234 XXXX XXXX XXXX"
  final String expiryDate;      // Format: "MM/YY"
  final String cvv;             // 3-digit
  final String cardHolderName;  // User's name
  final String accountNumber;   // Original 12-digit account

  VirtualCard({
    required this.cardNumber,
    required this.expiryDate,
    required this.cvv,
    required this.cardHolderName,
    required this.accountNumber,
  });

  factory VirtualCard.fromFirestore(Map<String, dynamic> data) {
    return VirtualCard(
      cardNumber: data['cardNumber'] ?? '',
      expiryDate: data['cardExpiry'] ?? '',
      cvv: data['cardCVV'] ?? '',
      cardHolderName: data['name'] ?? '',
      accountNumber: data['account_number'] ?? '',
    );
  }

  // Get masked card number (show last 4 digits)
  String get maskedNumber {
    if (cardNumber.length < 4) return cardNumber;
    final last4 = cardNumber.replaceAll(' ', '').substring(12);
    return '**** **** **** $last4';
  }

  // Get formatted card number with spaces
  String get formattedNumber {
    final clean = cardNumber.replaceAll(' ', '');
    if (clean.length != 16) return cardNumber;
    return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 12)} ${clean.substring(12, 16)}';
  }
}
