import 'package:flutter/material.dart';
import '/constants/colors.dart';

// Data Model for action grid buttons
class ActionItem {
  final IconData icon;
  final String label;
  final Color iconColor;

  const ActionItem({
    required this.icon,
    required this.label,
    required this.iconColor,
  });
}

// List of action items displayed in the grid
const List<ActionItem> actionItems = [
  ActionItem(
    icon: Icons.sync_alt, 
    label: 'Transfer', 
    iconColor: primaryGreen
  ),
  ActionItem(
    icon: Icons.call_received,
    label: 'Receive',
    iconColor: primaryGreen,
  ),
  ActionItem(
    icon: Icons.credit_card,
    label: 'Payment',
    iconColor: primaryGreen,
  ),
  ActionItem(
    icon: Icons.currency_exchange,
    label: 'Exchange',
    iconColor: primaryGreen,
  ),
  //add if you want to add grid
];
