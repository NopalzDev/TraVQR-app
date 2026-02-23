import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '/widgets/confirmation_page_widgets.dart';
import '/constants/colors.dart';
import 'success_page.dart';

enum TransactionType {
  transfer,
  qrPayment,
}

class TransactionConfirmationPage extends StatefulWidget {
  final String recipientName;
  final String recipientUserId;
  final double amount;
  final double senderBalance;
  final TransactionType transactionType;

  // Optional fields
  final String? accountNumber; // Only for transfers
  final String? category; // Only for transfers
  final String? note;

  const TransactionConfirmationPage({
    super.key,
    required this.recipientName,
    required this.recipientUserId,
    required this.amount,
    required this.senderBalance,
    required this.transactionType,
    this.accountNumber,
    this.category,
    this.note,
  });

  @override
  State<TransactionConfirmationPage> createState() =>
      _TransactionConfirmationPageState();
}

class _TransactionConfirmationPageState
    extends State<TransactionConfirmationPage> {
  bool _isProcessing = false;

  // Dynamic configuration based on transaction type
  String get pageTitle => widget.transactionType == TransactionType.transfer
      ? 'Confirm Transfer'
      : 'Approve Payment';

  String get amountLabel => widget.transactionType == TransactionType.transfer
      ? 'Transfer Amount'
      : 'Payment Amount';

  String get confirmButtonText =>
      widget.transactionType == TransactionType.transfer
          ? 'Confirm Transfer'
          : 'Confirm Payment';

  String get transactionTypeLabel =>
      widget.transactionType == TransactionType.transfer
          ? 'Transfer'
          : 'QR Payment';

  Future<void> _confirmTransaction() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final firestore = FirebaseFirestore.instance;
      final timestamp = Timestamp.now();

      // Use runTransaction for atomicity (works for both types)
      await firestore.runTransaction((transaction) async {
        // Fetch documents
        final senderDoc = await transaction.get(
          firestore.collection('users').doc(currentUser.uid),
        );
        final receiverDoc = await transaction.get(
          firestore.collection('users').doc(widget.recipientUserId),
        );

        if (!senderDoc.exists || !receiverDoc.exists) {
          throw Exception('User document not found');
        }

        final senderBalance =
            (senderDoc.data()?['account_balance'] ?? 0.0).toDouble();
        final receiverBalance =
            (receiverDoc.data()?['account_balance'] ?? 0.0).toDouble();

        if (senderBalance < widget.amount) {
          throw Exception('Insufficient balance');
        }

        // Update balances
        transaction.update(
          firestore.collection('users').doc(currentUser.uid),
          {'account_balance': senderBalance - widget.amount},
        );
        transaction.update(
          firestore.collection('users').doc(widget.recipientUserId),
          {'account_balance': receiverBalance + widget.amount},
        );

        // Create debit transaction for sender
        transaction.set(
          firestore.collection('transactions').doc(),
          {
            'userId': currentUser.uid,
            'type': 'debit',
            'transactionType': transactionTypeLabel,
            'amount': widget.amount,
            'description': transactionTypeLabel,
            'category': widget.category ?? 'General',
            'timestamp': timestamp,
            'note': widget.note ?? '',
            'recipientId': widget.recipientUserId,
            'recipientName': widget.recipientName,
            'recipient': widget.recipientName,
          },
        );

        // Create credit transaction for receiver
        transaction.set(
          firestore.collection('transactions').doc(),
          {
            'userId': widget.recipientUserId,
            'type': 'credit',
            'transactionType': transactionTypeLabel,
            'amount': widget.amount,
            'description': transactionTypeLabel,
            'category': widget.category ?? 'General',
            'timestamp': timestamp,
            'note': widget.note ?? '',
            'senderId': currentUser.uid,
            'senderName': senderDoc.data()?['name'] ?? 'User',
            'sender': senderDoc.data()?['name'] ?? 'User',
          },
        );
      });

      // Navigate to success page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SuccessPage(
              amount: widget.amount,
              recipientName: widget.recipientName,
              recipientAccountNumber: widget.accountNumber,
              category: widget.category,
              note: widget.note,
              transactionType: transactionTypeLabel,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAfter = widget.senderBalance - widget.amount;
    final now = DateTime.now();
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryGreen,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Recipient Card - account number only for transfers
                  ConfirmationRecipientCard(
                    recipientName: widget.recipientName,
                    accountNumber: widget.accountNumber, // null for QR payments
                    showVerifiedBadge: true,
                  ),

                  // Amount Display
                  ConfirmationAmountDisplay(
                    amount: widget.amount,
                    label: amountLabel,
                  ),

                  // Transaction Details
                  TransactionDetailsCard(
                    children: [
                      // Category - only for transfers
                      if (widget.category != null)
                        ConfirmationDetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: widget.category!,
                        ),

                      // Transaction Type - only for QR payments
                      if (widget.transactionType == TransactionType.qrPayment)
                        const ConfirmationDetailRow(
                          icon: Icons.qr_code_scanner_outlined,
                          label: 'Transaction Type',
                          value: 'QR Payment',
                        ),

                      // Note - if provided
                      if (widget.note != null && widget.note!.isNotEmpty)
                        ConfirmationDetailRow(
                          icon: Icons.note_outlined,
                          label: 'Note',
                          value: widget.note!,
                        ),

                      // Date
                      ConfirmationDetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: dateFormatter.format(now),
                      ),

                      // Time
                      ConfirmationDetailRow(
                        icon: Icons.access_time_outlined,
                        label: 'Time',
                        value: timeFormatter.format(now),
                      ),

                      // Balance After
                      ConfirmationDetailRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Balance After',
                        value: 'RM ${balanceAfter.toStringAsFixed(2)}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: ConfirmationActionButtons(
                onConfirm: _confirmTransaction,
                onCancel: () => Navigator.pop(context),
                confirmButtonText: confirmButtonText,
                isProcessing: _isProcessing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
