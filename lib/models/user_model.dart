import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String accountNumber;
  final double accountBalance;
  final String? cardNumber;
  final String? cardExpiry;
  final String? cardCVV;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.accountNumber,
    required this.accountBalance,
    this.cardNumber,
    this.cardExpiry,
    this.cardCVV,
    this.createdAt,
  });

  /// Factory constructor to create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      accountNumber: data['account_number'] ?? '',
      accountBalance: (data['account_balance'] ?? 0.0).toDouble(),
      cardNumber: data['cardNumber'],
      cardExpiry: data['cardExpiry'],
      cardCVV: data['cardCVV'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Factory constructor to create UserModel from Map
  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      accountNumber: data['account_number'] ?? '',
      accountBalance: (data['account_balance'] ?? 0.0).toDouble(),
      cardNumber: data['cardNumber'],
      cardExpiry: data['cardExpiry'],
      cardCVV: data['cardCVV'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'account_number': accountNumber,
      'account_balance': accountBalance,
      'cardNumber': cardNumber,
      'cardExpiry': cardExpiry,
      'cardCVV': cardCVV,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  // Computed properties
  String get formattedBalance => accountBalance.toStringAsFixed(2);

  String get balanceWithCurrency => 'RM $formattedBalance';

  String get formattedAccountNumber {
    if (accountNumber.length != 12) return accountNumber;
    return '${accountNumber.substring(0, 4)}-${accountNumber.substring(4, 8)}-${accountNumber.substring(8, 12)}';
  }

  String get initials {
    if (name.isEmpty) return 'A';
    final nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }
    return '${nameParts[0][0]}${nameParts[nameParts.length - 1][0]}'.toUpperCase();
  }

  String get firstName {
    if (name.isEmpty) return 'User';
    return name.split(' ').first;
  }

  bool get hasCard => cardNumber != null && cardNumber!.isNotEmpty;

  /// Copy with method for creating modified copies
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? accountNumber,
    double? accountBalance,
    String? cardNumber,
    String? cardExpiry,
    String? cardCVV,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      accountNumber: accountNumber ?? this.accountNumber,
      accountBalance: accountBalance ?? this.accountBalance,
      cardNumber: cardNumber ?? this.cardNumber,
      cardExpiry: cardExpiry ?? this.cardExpiry,
      cardCVV: cardCVV ?? this.cardCVV,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, accountNumber: $accountNumber, balance: $formattedBalance)';
  }
}
