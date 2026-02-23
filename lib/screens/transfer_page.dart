import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/constants/colors.dart';
import '/screens/confirmation_page.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isValidating = false;
  double? _senderBalance;
  double? _selectedQuickAmount;
  String? _recipientName;
  String? _recipientUserId;
  String? _selectedCategory;

  final List<String> _categories = [
    'Bills',
    'Food',
    'Shopping',
    'Transport',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadSenderBalance();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSenderBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _senderBalance = (doc.data()?['account_balance'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  Future<void> _validateAccountNumber() async {
    final accountNumber = _accountNumberController.text.trim();

    if (accountNumber.length != 12) {
      _showError('Account number must be 12 digits');
      return;
    }

    setState(() {
      _isValidating = true;
      _recipientName = null;
      _recipientUserId = null;
    });

    try {
      // Query Firestore for user with this account number
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('account_number', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showError('Account number not found');
        setState(() {
          _isValidating = false;
        });
        return;
      }

      final userData = querySnapshot.docs.first.data();
      final currentUser = FirebaseAuth.instance.currentUser;

      // Check if user is trying to transfer to themselves
      if (querySnapshot.docs.first.id == currentUser?.uid) {
        _showError('Cannot transfer to your own account');
        setState(() {
          _isValidating = false;
        });
        return;
      }

      setState(() {
        _recipientName = userData['name'] ?? 'Unknown';
        _recipientUserId = querySnapshot.docs.first.id;
        _isValidating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipient found: $_recipientName'),
          backgroundColor: primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error validating account: $e');
      _showError('Error validating account number');
      setState(() {
        _isValidating = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _navigateToConfirmation() async {
    // Validation
    if (_recipientName == null || _recipientUserId == null) {
      _showError('Please validate recipient account number first');
      return;
    }

    if (_amountController.text.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_senderBalance != null && amount > _senderBalance!) {
      _showError('Insufficient balance');
      return;
    }

    // Navigate to confirmation page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionConfirmationPage(
          recipientName: _recipientName!,
          recipientUserId: _recipientUserId!,
          amount: amount,
          senderBalance: _senderBalance!,
          transactionType: TransactionType.transfer,
          accountNumber: _accountNumberController.text,
          category: _selectedCategory,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        ),
      ),
    );

    // If transfer was successful, clear the form
    if (result == true && mounted) {
      _accountNumberController.clear();
      _amountController.clear();
      _noteController.clear();
      setState(() {
        _recipientName = null;
        _recipientUserId = null;
        _selectedCategory = null;
        _selectedQuickAmount = null;
      });
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Transfer Money',
          style: TextStyle(color: Colors.white),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Recipient Account Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recipient Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: InputDecoration(
                            hintText: 'Enter 12-digit account number',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(Icons.account_balance, color: secondaryGreen),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: secondaryGreen, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onChanged: (value) {
                            if (_recipientName != null) {
                              setState(() {
                                _recipientName = null;
                                _recipientUserId = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isValidating ? null : _validateAccountNumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isValidating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                              'Verify',
                              style: TextStyle(
                                color: Colors.white
                              ),
                            ),
                      ),
                    ],
                  ),
                  if (_recipientName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [secondaryGreen, primaryGreen],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(_recipientName!),
                                style: const TextStyle(
                                  color: secondaryGreen,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Verified Recipient',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _recipientName!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Amount Input Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Amount Buttons
                  const Text(
                    'Quick Select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [10, 20, 50, 100].map((amount) {
                      final isSelected = _selectedQuickAmount == amount.toDouble();
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedQuickAmount = amount.toDouble();
                                _amountController.text = amount.toString();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [secondaryGreen, primaryGreen],
                                      )
                                    : null,
                                color: isSelected ? null : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'RM $amount',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Amount Input
                  const Text(
                    'Enter Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      setState(() {
                        _selectedQuickAmount = double.tryParse(value);
                      });
                    },
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: secondaryGreen,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'RM ',
                      prefixStyle: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: secondaryGreen,
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.grey[300]),
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: secondaryGreen, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance Progress Bar
                  if (_senderBalance != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'RM ${_senderBalance!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: secondaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_amountController.text.isNotEmpty && _senderBalance! > 0)
                            ? (double.tryParse(_amountController.text) ?? 0) / _senderBalance!
                            : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          (double.tryParse(_amountController.text) ?? 0) > _senderBalance!
                              ? Colors.red
                              : secondaryGreen,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Category Dropdown
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    hint: const Text('Select category'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.category, color: secondaryGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: secondaryGreen, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Note Field
                  const Text(
                    'Add Note (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'E.g., Rent payment, Dinner split...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: secondaryGreen, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Transfer Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _navigateToConfirmation,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [secondaryGreen, primaryGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: secondaryGreen.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Transfer Money',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
