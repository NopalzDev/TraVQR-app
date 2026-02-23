import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/colors.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'debit' or 'credit'
  final String description;
  final String category;
  final String? transactionType;
  final double amount;
  final Timestamp? timestamp;
  final String? recipientName;
  final String? recipientAccountNumber;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.category,
    this.transactionType,
    required this.amount,
    this.timestamp,
    this.recipientName,
    this.recipientAccountNumber,
  });

  /// Factory constructor to create TransactionModel from Firestore document
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'debit',
      description: data['description'] ?? 'Transaction',
      category: data['category'] ?? 'General',
      transactionType: data['transactionType'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] as Timestamp?,
      recipientName: data['recipientName'],
      recipientAccountNumber: data['recipientAccountNumber'],
    );
  }

  /// Factory constructor to create TransactionModel from Map
  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'debit',
      description: data['description'] ?? 'Transaction',
      category: data['category'] ?? 'General',
      transactionType: data['transactionType'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] as Timestamp?,
      recipientName: data['recipientName'],
      recipientAccountNumber: data['recipientAccountNumber'],
    );
  }

  /// Convert TransactionModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'description': description,
      'category': category,
      'transactionType': transactionType,
      'amount': amount,
      'timestamp': timestamp,
      'recipientName': recipientName,
      'recipientAccountNumber': recipientAccountNumber,
    };
  }

  // Computed properties
  bool get isDebit => type == 'debit';

  bool get isCredit => type == 'credit';

  IconData get icon => isDebit ? Icons.call_made : Icons.call_received;

  Color get iconColor => isDebit ? Colors.red : primaryGreen;

  Color get amountColor => isDebit ? Colors.red : primaryGreen;

  String get formattedAmount => '${isDebit ? '-' : '+'}RM ${amount.toStringAsFixed(2)}';

  String get displayType {
    return transactionType ??
           (category == 'QR Payment' ? 'QR Payment' : 'Transfer');
  }

  String get displayName => recipientName ?? description;

  /// Format timestamp to readable date
  String get formattedDate {
    if (timestamp == null) return 'Unknown date';

    final date = timestamp!.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Copy with method for creating modified copies
  TransactionModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? description,
    String? category,
    String? transactionType,
    double? amount,
    Timestamp? timestamp,
    String? recipientName,
    String? recipientAccountNumber,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      description: description ?? this.description,
      category: category ?? this.category,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      recipientName: recipientName ?? this.recipientName,
      recipientAccountNumber: recipientAccountNumber ?? this.recipientAccountNumber,
    );
  }
}
