import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/qr_payment.dart';
import '../screens/transaction_page.dart';
import '../screens/transfer_page.dart';
import '../screens/card_page.dart';
import '../screens/account_page.dart';
import '../screens/settings_page.dart';
import '../screens/change_password_page.dart';

// App route names
class AppRoutes {
  static const String home = '/home';
  static const String qrPayment = '/qr_payment';
  static const String transaction = '/transaction';
  static const String transfer = '/transfer';
  static const String card = '/card';
  static const String account = '/account';
  static const String settings = '/settings';
  static const String changePassword = '/change_password';
}

// Route mappings
final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.home: (context) => const MyHomePage(),
  AppRoutes.qrPayment: (context) => const QrPaymentPage(),
  AppRoutes.transaction: (context) => const TransactionPage(),
  AppRoutes.transfer: (context) => const TransferPage(),
  AppRoutes.card: (context) => const CardPage(),
  AppRoutes.account: (context) => const AccountPage(),
  AppRoutes.settings: (context) => const SettingsPage(),
  AppRoutes.changePassword: (context) => const ChangePasswordPage(),
};

//before this in main.dart

// return MaterialApp(
  // Add named routes here
  // routes: {
  //   '/home': (context) => const MyHomePage(),
  //   '/qr_payment': (context) => const QrPaymentPage(),
  //   '/transaction': (context) => const TransactionPage(),
  //   '/transfer': (context) => const TransferPage(),
  //   '/card': (context) => const CardPage(),
  //   '/account': (context) => const AccountPage(),
  //   '/settings': (context) => const SettingsPage(),
  // },
// );