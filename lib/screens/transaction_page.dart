import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '/constants/colors.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String _filterType = 'all';

  // Advanced filter states
  Set<String> _selectedCategories = {};
  DateTimeRange? _selectedDateRange;
  double? _minAmount;
  double? _maxAmount;
  bool _showFilters = false;

  Stream<QuerySnapshot> _getTransactionStream(String userId) {
    Query query = FirebaseFirestore.instance
      .collection('transactions')
      .where('userId', isEqualTo: userId);

    //Apply filter if not 'all'
    if (_filterType != 'all') {
      query = query.where('type', isEqualTo: _filterType);
    }

    //Order by timestamp (newest first)
    query = query.orderBy('timestamp', descending: true);

    return query.snapshots();
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (_selectedDateRange != null) count++;
    if (_minAmount != null || _maxAmount != null) count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedDateRange = null;
      _minAmount = null;
      _maxAmount = null;
      _showFilters = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All filters cleared'),
        duration: Duration(seconds: 2),
        backgroundColor: primaryGreen,
      ),
    );
  }

  List<Map<String, dynamic>> _applyAdvancedFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Category filter
      if (_selectedCategories.isNotEmpty) {
        final category = data['category'] ?? '';
        if (!_selectedCategories.contains(category)) return false;
      }

      // Date range filter
      if (_selectedDateRange != null && data['timestamp'] != null) {
        final timestamp = data['timestamp'] as Timestamp;
        final date = timestamp.toDate();
        if (date.isBefore(_selectedDateRange!.start) ||
            date.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Amount filter
      final amount = (data['amount'] ?? 0.0).toDouble();
      if (_minAmount != null && amount < _minAmount!) return false;
      if (_maxAmount != null && amount > _maxAmount!) return false;

      return true;
    }).map((doc) => {
      'doc': doc,
      'data': doc.data() as Map<String, dynamic>,
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transaction History'), 
          backgroundColor: primaryGreen,
        ),
        body: const Center(
          child: Text('Please log in to view transactions'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryGreen,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: AnimatedRotation(
                  turns: _showFilters ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.filter_list, color: Colors.white),
                ),
              ),
              if (_getActiveFilterCount() > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        '${_getActiveFilterCount()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        //Apply gradient here
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0, //used to create a shadow effect
      ),
      body: Column(
        children: [
          _buildFilterButtons(),
          _buildAdvancedFilters(),
          _buildActiveFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getTransactionStream(user.uid), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[300], size: 60),
                        const SizedBox(height: 15),
                        Text(
                          'Error loading transactions',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        )
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Text(
                        //   'Your transaction will appear here',
                        //   style: TextStyle(
                        //     color: Colors.grey[500],
                        //     fontSize: 14,
                        //   ),
                        // )
                      ],
                    ),
                  );
                }

                // Apply advanced filters
                final filteredTransactions = _applyAdvancedFilters(snapshot.data!.docs);

                if (filteredTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'No transactions match your filters',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearAllFilters,
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final doc = filteredTransactions[index]['doc'] as QueryDocumentSnapshot;
                    final data = filteredTransactions[index]['data'] as Map<String, dynamic>;

                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: TransactionCard(
                        transactionId: doc.id,
                        type: data['type'] ?? 'debit',
                        category: data['category'] ?? 'General',
                        transactionType: data['transactionType'],
                        amount: (data['amount'] ?? 0.0).toDouble(),
                        timestamp: data['timestamp'] as Timestamp?,
                        note: data['note'],
                        recipient: data['recipient'],
                        sender: data['sender'],
                      ),
                    );
                  },
                );
              }
            )
          )
        ],
      ),
    );
  }

  //Semua button filter
  Widget _buildFilterButtons() { //Semua button
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton('All', 'all')
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterButton('Sent', 'debit')
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterButton('Received', 'credit')
          ),
        ],
      ),
    );
  }

  //Single button
  Widget _buildFilterButton(String label, String value) {
    final isSelected = _filterType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _showFilters ? null : 0,
      child: _showFilters
          ? Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category filters
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'QR Payment',
                      'Transfer',
                      'Top Up',
                      'Bill Payment',
                      'General',
                    ].map((category) => _buildCategoryChip(category)).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Date range picker
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _selectedDateRange == null
                                ? 'Select Date Range'
                                : '${DateFormat('d MMM').format(_selectedDateRange!.start)} - ${DateFormat('d MMM yyyy').format(_selectedDateRange!.end)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _selectedDateRange == null ? Colors.grey[700] : primaryGreen,
                            side: BorderSide(
                              color: _selectedDateRange == null ? Colors.grey[300]! : primaryGreen,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                        ),
                      ),
                      if (_selectedDateRange != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedDateRange = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.grey[600],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Amount range
                  const Text(
                    'Amount Range (RM)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Min',
                            hintText: '0.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _minAmount = double.tryParse(value);
                            });
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Max',
                            hintText: '999.99',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _maxAmount = double.tryParse(value);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Clear filters button
                  if (_getActiveFilterCount() > 0)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _clearAllFilters,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear All Filters'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategories.contains(category);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCategories.remove(category);
          } else {
            _selectedCategories.add(category);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    if (_getActiveFilterCount() == 0) {
      return const SizedBox.shrink();
    }

    List<Widget> chips = [];

    // Category chips
    for (var category in _selectedCategories) {
      chips.add(_buildActiveChip('Category: $category', () {
        setState(() {
          _selectedCategories.remove(category);
        });
      }));
    }

    // Date range chip
    if (_selectedDateRange != null) {
      chips.add(_buildActiveChip(
        'Date: ${DateFormat('d MMM').format(_selectedDateRange!.start)} - ${DateFormat('d MMM yyyy').format(_selectedDateRange!.end)}',
        () {
          setState(() {
            _selectedDateRange = null;
          });
        },
      ));
    }

    // Amount range chip
    if (_minAmount != null || _maxAmount != null) {
      String amountText = 'Amount: ';
      if (_minAmount != null && _maxAmount != null) {
        amountText += 'RM ${_minAmount!.toStringAsFixed(2)} - RM ${_maxAmount!.toStringAsFixed(2)}';
      } else if (_minAmount != null) {
        amountText += '≥ RM ${_minAmount!.toStringAsFixed(2)}';
      } else {
        amountText += '≤ RM ${_maxAmount!.toStringAsFixed(2)}';
      }
      chips.add(_buildActiveChip(amountText, () {
        setState(() {
          _minAmount = null;
          _maxAmount = null;
        });
      }));
    }

    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips,
        ),
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: primaryGreen,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 16,
              color: primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }
}

//Transactions Card Widget
class TransactionCard extends StatelessWidget {
  final String transactionId;
  final String type;
  final String category;
  final String? transactionType;
  final double amount;
  final Timestamp? timestamp;
  final String? recipient;
  final String? sender;
  final String? note;

  const TransactionCard({
    super.key,
    required this.transactionId,
    required this.type,
    required this.category,
    this.transactionType,
    required this.amount,
    this.timestamp,
    this.recipient,
    this.sender,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = type == 'debit';
    final icon = isDebit ? Icons.call_made : Icons.call_received;
    final iconColor = isDebit ? Colors.red : Colors.green;
    final amountText = '${isDebit ? '-' : '+'}RM${amount.toStringAsFixed(2)}';
    final amountColor = isDebit ? Colors.red : Colors.green;

    // Display category in badge, default to 'General' if empty
    final displayType = (category.isEmpty || category == 'QR Payment' || category == 'Transfer')
        ? 'General'
        : category;

    String formattedDate = 'Unknown date';
    if (timestamp != null) {
      final date = timestamp!.toDate();
      formattedDate = DateFormat('d MMM yyyy, h:mm a').format(date);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          _showTransactionDetails(context);
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: iconColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transactionType ?? 'Transfer',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Show recipient/sender
                    if ((isDebit && recipient != null && recipient!.isNotEmpty) ||
                        (!isDebit && sender != null && sender!.isNotEmpty)) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 13,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isDebit ? 'To: $recipient' : 'From: $sender',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                )
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayType,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context) {
    final isDebit = type == 'debit';
    final iconColor = isDebit ? Colors.red : Colors.green;
    final amountText = '${isDebit ? '-' : '+'} RM${amount.toStringAsFixed(2)}';
    final amountColor = isDebit ? Colors.red : Colors.green;

    // Determine transaction type with fallback for backward compatibility
    final displayType = transactionType ??
        (category == 'QR Payment' ? 'QR Payment' : 'Transfer');

    String formattedDate = 'Unknown date';
    if (timestamp != null) {
      final date = timestamp!.toDate();
      formattedDate = DateFormat('d MMM yyyy, h:mm a').format(date);
    }

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          )
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                //Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                //Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(
                    isDebit ? Icons.call_made : Icons.call_received,
                    color: iconColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),

                //Amount
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: amountColor
                  ),
                ),
                const SizedBox(height: 8),

                //Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                //Details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                       _buildDetailRow('Transaction Type', displayType, Icons.payment_rounded),
                      const Divider(height: 24),
                      _buildDetailRow('Status', isDebit ? 'Sent' : 'Received', Icons.sync_alt),
                      const Divider(height: 24),
                      _buildDetailRow('Category', category, Icons.category_outlined),
                      if (recipient != null) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Recipient', recipient!, Icons.person_outline),
                      ],
                      if (sender != null) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Sender', sender!, Icons.person_outline),
                      ],
                      const Divider(height: 24),
                      _buildDetailRow('Date & Time', formattedDate, Icons.access_time),
                      if (note != null && note!.isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Note', note!, Icons.description_outlined),
                      ],
                      const Divider(height: 24),
                      _buildDetailRow('Transaction ID', transactionId.substring(0,16) + '...', Icons.numbers_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                //Close Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      )
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  ),
                )
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              )
            ],
          )
        )
      ],
    );
  }
}