import 'package:cloud_firestore/cloud_firestore.dart';

class LoginLockoutService {
  static const int maxAttempts = 3;
  static const int lockoutDurationMinutes = 3; // Set to 5 minutes for testing (change to 60 for production)

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a user is currently locked out
  /// Returns a map with 'isLockedOut' and optional 'remainingMinutes'
  Future<Map<String, dynamic>> checkLockoutStatus(String email) async {
    try {
      final docRef = _firestore.collection('login_attempts').doc(email.toLowerCase());
      final doc = await docRef.get();

      if (!doc.exists) {
        return {'isLockedOut': false};
      }

      final data = doc.data()!;
      final failedAttempts = data['failed_attempts'] as int? ?? 0;
      final lockoutUntil = (data['lockout_until'] as Timestamp?)?.toDate();

      // Check if user has reached max attempts and has a lockout time
      if (failedAttempts >= maxAttempts && lockoutUntil != null) {
        final now = DateTime.now();

        if (now.isBefore(lockoutUntil)) {
          // User is still locked out
          final remainingDuration = lockoutUntil.difference(now);
          final remainingMinutes = remainingDuration.inMinutes + 1;

          return {
            'isLockedOut': true,
            'remainingMinutes': remainingMinutes,
          };
        } else {
          // Lockout period has expired, reset the attempts
          await _resetAttempts(email);
          return {'isLockedOut': false};
        }
      }

      return {'isLockedOut': false};
    } catch (e) {
      // If there's an error checking lockout status, allow login attempt
      // This prevents legitimate users from being blocked due to database issues
      return {'isLockedOut': false};
    }
  }

  /// Record a failed login attempt
  Future<void> recordFailedAttempt(String email) async {
    try {
      final docRef = _firestore.collection('login_attempts').doc(email.toLowerCase());
      final doc = await docRef.get();

      if (!doc.exists) {
        // First failed attempt
        await docRef.set({
          'email': email.toLowerCase(),
          'failed_attempts': 1,
          'last_attempt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data()!;
        final currentAttempts = (data['failed_attempts'] as int? ?? 0) + 1;

        if (currentAttempts >= maxAttempts) {
          // Lock out the user
          final lockoutUntil = DateTime.now().add(
            Duration(minutes: lockoutDurationMinutes),
          );

          await docRef.update({
            'failed_attempts': currentAttempts,
            'last_attempt': FieldValue.serverTimestamp(),
            'lockout_until': Timestamp.fromDate(lockoutUntil),
          });
        } else {
          // Increment failed attempts
          await docRef.update({
            'failed_attempts': currentAttempts,
            'last_attempt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      // Silently fail - don't prevent login if database write fails
      print('Error recording failed attempt: $e');
    }
  }

  /// Reset failed attempts after successful login
  Future<void> resetAttempts(String email) async {
    await _resetAttempts(email);
  }

  Future<void> _resetAttempts(String email) async {
    try {
      final docRef = _firestore.collection('login_attempts').doc(email.toLowerCase());
      await docRef.delete();
    } catch (e) {
      // Silently fail
      print('Error resetting attempts: $e');
    }
  }

  /// Get remaining attempts before lockout
  Future<int> getRemainingAttempts(String email) async {
    try {
      final docRef = _firestore.collection('login_attempts').doc(email.toLowerCase());
      final doc = await docRef.get();

      if (!doc.exists) {
        return maxAttempts;
      }

      final data = doc.data()!;
      final failedAttempts = data['failed_attempts'] as int? ?? 0;
      final remaining = maxAttempts - failedAttempts;

      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return maxAttempts;
    }
  }
}
