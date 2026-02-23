import 'package:flutter/material.dart';

import '/constants/colors.dart';
import '/constants/routes.dart';
import '/widgets/settings_list_item.dart';
import '/widgets/settings_section.dart';
import '/utils/notification_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Preferences
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    final notifEnabled = await NotificationPreferences.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifEnabled;
      });
    }
  }

  /// Navigate to change password page
  void _showChangePasswordDialog() {
    Navigator.pushNamed(context, AppRoutes.changePassword);
  }

  /// Handle notification preference change
  void _onNotificationChanged(bool value) {
    setState(() => _notificationsEnabled = value);
    NotificationPreferences.setNotificationsEnabled(value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Notifications enabled' : 'Notifications disabled',
        ),
        backgroundColor: primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Settings',
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
          const SizedBox(height: 24),

          // Security Section
          SettingsSection(
            title: 'Security',
            children: [
              SettingsListItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: _showChangePasswordDialog,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Preferences Section
          SettingsSection(
            title: 'Preferences',
            children: [
              SettingsListItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Enable push notifications',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: _onNotificationChanged,
                  activeTrackColor: primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
        ),
      ),
    );
  }
}
