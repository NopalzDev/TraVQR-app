import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '/constants/colors.dart';
import '/constants/routes.dart';
import '/models/transaction_model.dart';

// Data model for daily transaction activity
class DailyActivity {
  double sent;
  double received;
  final DateTime date;

  DailyActivity({
    this.sent = 0,
    this.received = 0,
    required this.date,
  });

  double get total => sent + received;
  bool get hasActivity => total > 0;
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _name = '';
  String _email = '';
  String _accountNumber = '';
  String _balance = '0.00';
  bool _isLoading = true;
  List<DailyActivity> _weeklyActivity = [];
  bool _isLoadingActivity = true;
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadWeeklyTransactions();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _email = user.email ?? '');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final userData = docSnapshot.data()!;
        if (mounted) {
          setState(() {
            _name = userData['name'] ?? 'User';
            _balance = (userData['account_balance'] is num)
                ? userData['account_balance'].toStringAsFixed(2)
                : '0.00';
            _accountNumber = userData['account_number'] ?? 'xxxxxxxxxxxx';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWeeklyTransactions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create list of last 7 days (6 days ago to today)
      List<DailyActivity> activityList = [];
      for (int i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        activityList.add(DailyActivity(date: date));
      }

      // Calculate 7 days ago for Firestore query
      final sevenDaysAgo = today.subtract(const Duration(days: 6));
      final sevenDaysAgoTimestamp = Timestamp.fromDate(sevenDaysAgo);

      // Query Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgoTimestamp)
          .get();

      // Process transactions and add to corresponding day
      for (var doc in querySnapshot.docs) {
        final transaction = TransactionModel.fromFirestore(doc);
        if (transaction.timestamp == null) continue;

        final transactionDate = transaction.timestamp!.toDate();
        final transactionDay = DateTime(
          transactionDate.year,
          transactionDate.month,
          transactionDate.day,
        );

        // Find matching day in our list
        final dayIndex = activityList.indexWhere(
          (activity) => activity.date.isAtSameMomentAs(transactionDay),
        );

        if (dayIndex != -1) {
          if (transaction.isDebit) {
            activityList[dayIndex].sent += transaction.amount;
          } else if (transaction.isCredit) {
            activityList[dayIndex].received += transaction.amount;
          }
        }
      }

      if (mounted) {
        setState(() {
          _weeklyActivity = activityList;
          _isLoadingActivity = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingActivity = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Account',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [primaryGreen, secondaryGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _name.isNotEmpty ? _name[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    _email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Weekly Spending Section
            _buildWeeklyActivitySection(),

            const SizedBox(height: 24),

            // Menu Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Menu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Menu Items
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.credit_card_rounded,
                    title: 'My Cards',
                    // onTap: () => Navigator.pushNamed(context, '/card'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.card),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: 'Transaction History',
                    // onTap: () => Navigator.pushNamed(context, '/transaction'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.transaction),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Transfer Money',
                    // onTap: () => Navigator.pushNamed(context, '/transfer'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.transfer),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    // onTap: () => Navigator.pushNamed(context, '/settings'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildWeeklyActivitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(),
          const SizedBox(height: 16),
          if (_isLoadingActivity)
            _buildLoadingSkeleton()
          else
            _buildWeeklyBars(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Spending',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last 7 days',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
          children: [
            _buildLegendItem('\$ In', successGreen),
            const SizedBox(width: 12),
            _buildLegendItem('\$ Out', errorRed),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildWeeklyBars() {
    // Find max amount for scaling
    double maxAmount = 0;
    for (var activity in _weeklyActivity) {
      if (activity.total > maxAmount) maxAmount = activity.total;
    }

    if (maxAmount == 0) return _buildEmptyState();

    const double chartHeight = 140.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          // Amount display
          if (_selectedDayIndex != null)
            _buildAmountDisplay(_weeklyActivity[_selectedDayIndex!])
          else
            _buildTotalAmountDisplay(),
          const SizedBox(height: 12),
          // Chart
          SizedBox(
            height: chartHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final spacing = constraints.maxWidth / (_weeklyActivity.length - 1);

                    // Find the closest point
                    int closestIndex = 0;
                    double minDistance = double.infinity;

                    for (int i = 0; i < _weeklyActivity.length; i++) {
                      final x = i * spacing;
                      final distance = (localPosition.dx - x).abs();
                      if (distance < minDistance) {
                        minDistance = distance;
                        closestIndex = i;
                      }
                    }

                    setState(() {
                      _selectedDayIndex = closestIndex;
                    });
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, chartHeight),
                    painter: ActivityLinePainter(
                      activities: _weeklyActivity,
                      maxAmount: maxAmount,
                      selectedIndex: _selectedDayIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Date labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weeklyActivity.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final isToday = activity.date.isAtSameMomentAs(today);
              final isSelected = _selectedDayIndex == index;

              final dayLabel = isToday
                  ? 'Today'
                  : DateFormat('EEE').format(activity.date);

              return Expanded(
                child: Text(
                  dayLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.black87 : Colors.grey[700],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(DailyActivity activity) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (activity.sent > 0) ...[
            Icon(Icons.arrow_upward, size: 16, color: errorRed),
            const SizedBox(width: 4),
            Text(
              'RM ${activity.sent.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: errorRed,
              ),
            ),
          ],
          if (activity.sent > 0 && activity.received > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 1,
                height: 16,
                color: Colors.grey[300],
              ),
            ),
          if (activity.received > 0) ...[
            Icon(Icons.arrow_downward, size: 16, color: successGreen),
            const SizedBox(width: 4),
            Text(
              'RM ${activity.received.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: successGreen,
              ),
            ),
          ],
          if (!activity.hasActivity)
            Text(
              'No activity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountDisplay() {
    double totalSent = 0;
    double totalReceived = 0;

    for (var activity in _weeklyActivity) {
      totalSent += activity.sent;
      totalReceived += activity.received;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_upward, size: 16, color: errorRed),
          const SizedBox(width: 4),
          Text(
            'RM ${totalSent.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: errorRed,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 1,
              height: 16,
              color: Colors.grey[300],
            ),
          ),
          Icon(Icons.arrow_downward, size: 16, color: successGreen),
          const SizedBox(width: 4),
          Text(
            'RM ${totalReceived.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: successGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No transactions this week',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 60 + (index * 10.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 30,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Custom painter for the activity line chart
class ActivityLinePainter extends CustomPainter {
  final List<DailyActivity> activities;
  final double maxAmount;
  final int? selectedIndex;

  ActivityLinePainter({
    required this.activities,
    required this.maxAmount,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activities.isEmpty || maxAmount == 0) return;

    // Calculate spacing between points
    final double spacing = size.width / (activities.length - 1);

    // Create paths for both lines
    final Path sentPath = Path();
    final Path receivedPath = Path();
    final List<Offset> sentPoints = [];
    final List<Offset> receivedPoints = [];

    // Calculate points for both sent and received
    for (int i = 0; i < activities.length; i++) {
      final x = i * spacing;

      // Calculate Y position for sent money (red line)
      final sentY = size.height - (activities[i].sent / maxAmount * size.height);
      sentPoints.add(Offset(x, sentY));

      if (i == 0) {
        sentPath.moveTo(x, sentY);
      } else {
        sentPath.lineTo(x, sentY);
      }

      // Calculate Y position for received money (green line)
      final receivedY = size.height - (activities[i].received / maxAmount * size.height);
      receivedPoints.add(Offset(x, receivedY));

      if (i == 0) {
        receivedPath.moveTo(x, receivedY);
      } else {
        receivedPath.lineTo(x, receivedY);
      }
    }

    // Paint for green line (received)
    final receivedPaint = Paint()
      ..color = successGreen
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Paint for red line (sent)
    final sentPaint = Paint()
      ..color = errorRed
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw green line first (background)
    canvas.drawPath(receivedPath, receivedPaint);

    // Draw red line on top (foreground)
    canvas.drawPath(sentPath, sentPaint);

    // Draw dots for received money (green)
    final receivedDotPaint = Paint()
      ..color = successGreen
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < receivedPoints.length; i++) {
      final point = receivedPoints[i];
      final isSelected = selectedIndex == i;
      if (point.dy < size.height) { // Only draw if there's activity
        canvas.drawCircle(point, isSelected ? 6.5 : 5.0, dotBorderPaint);
        canvas.drawCircle(point, isSelected ? 5.0 : 3.5, receivedDotPaint);
      }
    }

    // Draw dots for sent money (red) - on top
    final sentDotPaint = Paint()
      ..color = errorRed
      ..style = PaintingStyle.fill;

    for (int i = 0; i < sentPoints.length; i++) {
      final point = sentPoints[i];
      final isSelected = selectedIndex == i;
      if (point.dy < size.height) { // Only draw if there's activity
        canvas.drawCircle(point, isSelected ? 6.5 : 5.0, dotBorderPaint);
        canvas.drawCircle(point, isSelected ? 5.0 : 3.5, sentDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(ActivityLinePainter oldDelegate) {
    return oldDelegate.activities != activities ||
        oldDelegate.maxAmount != maxAmount ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
