import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/widgets/bottom_nav_bar.dart';
import '/constants/colors.dart';
import '/constants/routes.dart';
import '/widgets/concave_bottom_clipper.dart';
import '/screens/settings_page.dart';
import '/screens/card_page.dart';
import '/models/action_item_model.dart';

// 3. MAIN PAGE STRUCTURE
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    //Handle navigation to different pages
    switch (index) {
      case 0: //Already on Home, just update selected index
        setState(() {
          _selectedIndex = index;
        });
        break;
      case 1: //Navigate to Account page
        // Navigator.pushNamed(context, '/account');
        Navigator.pushNamed(context, AppRoutes.account);
        break;
      case 2: //Navigate to qr page (qr_payment.dart)
        // Navigator.pushNamed(context, '/qr_payment');
        Navigator.pushNamed(context, AppRoutes.qrPayment);
        break;
      case 3: //Navigate to card page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CardPage()),
        );
        break;
      case 4: //Navigate to settings page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),

      body: const _HomePageContent(),

      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),

      floatingActionButton: CustomFloatingActionButton(
        onPressed: () => _onItemTapped(2),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// 4. PAGE CONTENT LAYOUT (modified for data fetching)
class _HomePageContent extends StatefulWidget {
  const _HomePageContent();

  @override
  State<_HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent> {
  // State variables
  String _name = 'User';
  String _balance = '0.00';
  String _accountNumber = 'xxxxxxxxxxxx';
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Fetch user data from Firestore and update state
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setFallbackData();
        return;
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final userData = docSnapshot.data()!;
        setState(() {
          _name = userData['name'] ?? 'User';
          _balance = (userData['account_balance'] is num)
              ? userData['account_balance'].toStringAsFixed(2)
              : '0.00';
          _accountNumber = userData['account_number'] ?? 'xxxxxxxxxxxx';
          _isLoading = false;
        });
      } else {
        _setFallbackData();
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      _setFallbackData();
    }
  }

  // Set fallback data for error states
  void _setFallbackData() {
    if (!mounted) return;
    setState(() {
      _name = 'Guest';
      _balance = '0.00';
      _accountNumber = 'xxxxxxxxxxxx';
      _isLoading = false;
    });
  }

  // Handle pull-to-refresh
  Future<void> _handleRefresh() async {
    await _loadUserData();
    // Add small delay to ensure smooth animation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator on initial load
    if (_isLoading && _balance == '0.00') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: CircularProgressIndicator(color: primaryGreen),
        ),
      );
    }

    // Wrap with RefreshIndicator for pull-to-refresh
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: primaryGreen,
      backgroundColor: Colors.white,
      child: _buildContent(
        name: _name,
        balance: _balance,
        accountNumber: _accountNumber,
      ),
    );
  }

  //Helper method to build the main scrollable content (LAYOUT)
  Widget _buildContent({
    required String name,
    required String balance,
    required String accountNumber,
  }) {
    return SingleChildScrollView(
      child: Column(
        children: [
          //Pass dynamic data to children
          SizedBox(
            height: 380, //size from top bar to before transaction section
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                HeaderSection(name: name),
                Positioned(
                  top: 150, //space above card
                  left: 0,
                  right: 0,
                  child: BankCardWidget(
                    name: name,
                    balance: balance,
                    accountNumber: accountNumber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TransactionHistorySection(),
        ],
      ),
    );
  }
}

// 5. HEADER SECTION
// Top section with gradient background and greeting
class HeaderSection extends StatelessWidget {
  final String name; //new parameter for dynamic data
  const HeaderSection({super.key, required this.name}); //Updated constructor

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        //Gradient background with concave bottom curve
        ClipPath(
          clipper: ConcaveBottomClipper(),
          child: Container(
            height:
                300, //height black section behind card with curve background
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryBlack, primaryBlack],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
        ),

        //Content Overlay
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 20),
              _buildGreeting(),
            ],
          ),
        ),
      ],
    );
  }

  // App bar with title and action icons
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'TraVQR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            _buildCircleIcon(Icons.chat_bubble_outline_rounded),
            const SizedBox(width: 8),
            _buildCircleIcon(Icons.notifications),
            const SizedBox(width: 8),
            _buildCircleIconWithAction(Icons.logout_rounded, () {
              _showLogoutConfirmation(context);
            }),
          ],
        ),
      ],
    );
  }

  //Circular icon button
  Widget _buildCircleIcon(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.3),
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  //Circular icon button with action
  Widget _buildCircleIconWithAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.3),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // User greeting section
  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peace be Upon You 👋,',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show modern logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logout Icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 35,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                const Text(
                  'Are you sure you want to logout?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),

                // Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: BorderSide(color: primaryGreen, width: 1.5),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Logout Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await FirebaseAuth.instance.signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 6. BANK CARD WIDGET
class BankCardWidget extends StatefulWidget {
  final String name;
  final String balance;
  final String accountNumber;

  const BankCardWidget({
    super.key,
    required this.name,
    required this.balance,
    required this.accountNumber,
  });

  @override
  State<BankCardWidget> createState() => _BankCardWidgetState();
}

class _BankCardWidgetState extends State<BankCardWidget> {
  bool _isBalanceVisible = true; //controls show/hide
  String _maskBalance(String balance) {
    // Ensure any spacing or formatting is removed
    String trimmed = balance.trim();
    // Build mask
    return trimmed
        .split('')
        .map((char) {
          if (char == '.') {
            return '.'; // keep decimal point
          }
          return '*'; // replace numbers with bullets
        })
        .join('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: const EdgeInsets.all(20),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [primaryGreen, secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 35,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildBalanceDisplay(),
          const SizedBox(height: 8),
          _buildAccNumber(),
          const SizedBox(height: 16),
          _buildCircularActions(context),
        ],
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Balance',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            // Balance text (shown or hidden)
            Text(
              _isBalanceVisible
                  ? 'RM ${widget.balance}'
                  : 'RM ${_maskBalance(widget.balance)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 12),

            // Eye icon to toggle visibility
            GestureDetector(
              onTap: () {
                setState(() {
                  _isBalanceVisible = !_isBalanceVisible;
                });
              },
              child: Icon(
                _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
                size: 25,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccNumber() {
    // Format account number as: 1234 - 5678 - 9012
    final accNumText =
        '${widget.accountNumber.substring(0, 4)}-'
        '${widget.accountNumber.substring(4, 8)}-'
        '${widget.accountNumber.substring(8, 12)}';

    return Text(
      accNumText,
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildCircularActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < actionItems.length; i++) ...[
          if (i > 0) const SizedBox(width: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              switch (actionItems[i].label) {
                case 'Transfer':
                  // Navigator.pushNamed(context, '/transfer');
                  Navigator.pushNamed(context, AppRoutes.transfer);
                  break;
                case 'Receive':
                  // Navigator.pushNamed(context, '/qr_payment');
                  Navigator.pushNamed(context, AppRoutes.qrPayment);
                  break;
                case 'Payment':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('\'Payment\' feature coming soon'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  break;
                case 'Exchange':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('\'Exchange\' feature coming soon'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  break;
                default:
                  print('Tapped ${actionItems[i].label}');
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                  ),
                  child: Icon(
                    actionItems[i].icon,
                    color: Colors.black54,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  actionItems[i].label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// 7. TRANSACTION HISTORY SECTION
class TransactionHistorySection extends StatelessWidget {
  const TransactionHistorySection({super.key});

  Stream<QuerySnapshot> _getTransactionStream(String userId) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return SizedBox.shrink();
    }

    return Container(
      color: Colors.transparent,
      margin: const EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            _buildSectionHeader(context),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _getTransactionStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: List.generate(
                      3,
                      (index) => const _TransactionRowSkeleton(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('Transaction error: ${snapshot.error}');
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Error loading transactions',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data!.docs;

                return Column(
                  children: transactions.take(5).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return TransactionRow(
                      type: data['type'] ?? 'debit',
                      description: data['description'] ?? 'Transaction',
                      category: data['category'] ?? 'General',
                      transactionType: data['transactionType'],
                      amount: (data['amount'] ?? 0.0).toDouble(),
                      timestamp: data['timestamp'] as Timestamp?,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Section header with See All button
Widget _buildSectionHeader(BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Transaction History',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      TextButton(
        onPressed: () {
          // Navigator.pushNamed(context, '/transaction');
          Navigator.pushNamed(context, AppRoutes.transaction);
        },
        child: const Text(
          'See All',
          style: TextStyle(
            fontSize: 16,
            color: primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

//Transaction row  with real data
class TransactionRow extends StatelessWidget {
  final String type;
  final String description;
  final String category;
  final String? transactionType;
  final double amount;
  final Timestamp? timestamp;

  const TransactionRow({
    super.key,
    required this.type,
    required this.description,
    required this.category,
    this.transactionType,
    required this.amount,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = type == 'debit';
    final icon = isDebit ? Icons.call_made : Icons.call_received;
    final iconColor = isDebit ? Colors.red : primaryGreen;
    final amountText = '${isDebit ? '-' : '+'}RM ${amount.toStringAsFixed(2)}';
    final amountColor = isDebit ? Colors.red : Colors.green;

    // Determine transaction type with fallback for backward compatibility
    final displayType =
        transactionType ??
        (category == 'QR Payment' ? 'QR Payment' : 'Transfer');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildicon(icon, iconColor),
          const SizedBox(width: 12),
          _buildDetails(description, displayType),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildicon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildDetails(String title, String subtitle) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

//Single Transaction row with skeleton loading effect
class _TransactionRowSkeleton extends StatelessWidget {
  const _TransactionRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _buildIconPlaceholder(),
          const SizedBox(width: 15),
          _buildDetailsPlaceholder(),
          const SkeletonContainer(width: 70, height: 16, radius: 4),
        ],
      ),
    );
  }
}

// Transaction icon placeholder
Widget _buildIconPlaceholder() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: const SkeletonContainer(width: 24, height: 24, radius: 4),
  );
}

//Transaction detail placeholder(title & category)
Widget _buildDetailsPlaceholder() {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonContainer(width: 120, height: 16, radius: 4),
        SizedBox(height: 5),
        SkeletonContainer(width: 80, height: 14, radius: 4),
      ],
    ),
  );
}

// 9. Utility Widget
class SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonContainer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
