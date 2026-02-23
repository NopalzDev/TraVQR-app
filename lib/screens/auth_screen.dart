import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/constants/colors.dart';
import '/utils/password_validator.dart';
import '/utils/account_number_generator.dart';
import '/utils/login_lockout_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;
  bool isLockedOut = false;
  int lockoutRemainingMinutes = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LoginLockoutService _lockoutService = LoginLockoutService();

  // Password strength tracking
  int _passwordStrength = 0;
  String _passwordHint = '';
  @override
  void initState() {
    super.initState();
    // Listen to password changes for real-time strength updates
    _passwordController.addListener(_updatePasswordStrength);
    // Listen to email changes to check lockout status
    _emailController.addListener(_checkLockoutStatus);
  }
  void _updatePasswordStrength() {
    if (!mounted) return;

    final password = _passwordController.text;
    setState(() {
      _passwordStrength = PasswordValidator.getStrengthScore(password);
      _passwordHint = PasswordValidator.getMissingRequirements(password);
    });
  }

  // Check lockout status when email changes
  Future<void> _checkLockoutStatus() async {
    if (!mounted || !isLogin) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        isLockedOut = false;
        lockoutRemainingMinutes = 0;
      });
      return;
    }

    try {
      final lockoutStatus = await _lockoutService.checkLockoutStatus(email);
      if (mounted) {
        setState(() {
          isLockedOut = lockoutStatus['isLockedOut'] ?? false;
          lockoutRemainingMinutes = lockoutStatus['remainingMinutes'] ?? 0;
        });
      }
    } catch (e) {
      // Silently fail - don't show error to user for status check
    }
  }

  //
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.removeListener(_checkLockoutStatus);
    _emailController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
      _formKey.currentState?.reset();
      isLockedOut = false;
      lockoutRemainingMinutes = 0;
    });
    // Check lockout status if switching to login
    if (isLogin) {
      _checkLockoutStatus();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Authentication Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), 
            child: const Text('OK'),
          )
        ],
      )
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        // Check if user is locked out before attempting login
        final lockoutStatus = await _lockoutService.checkLockoutStatus(_emailController.text.trim());

        if (lockoutStatus['isLockedOut'] == true) {
          final remainingMinutes = lockoutStatus['remainingMinutes'] as int;
          setState(() {
            isLoading = false;
          });
          _showErrorDialog(
            'Account temporarily locked due to multiple failed login attempts. '
            'Please try again in $remainingMinutes minute${remainingMinutes > 1 ? 's' : ''}.'
          );
          return;
        }

        //Login with email and password
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Reset failed attempts on successful login
        await _lockoutService.resetAttempts(_emailController.text.trim());
        // Clear lockout state
        setState(() {
          isLockedOut = false;
          lockoutRemainingMinutes = 0;
        });
        _showSuccessSnackbar('Welcome back!');
      } else {
        //Sign up with email and password
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(), 
          password: _passwordController.text,
        );

        //Update display name
        await userCredential.user?.updateDisplayName(_nameController.text.trim());

        //Save user details to Firestore
        if (userCredential.user != null) {
          //Generate unique account number
          final accountNumber = await AccountNumberGenerator.generate();

          //Get a reference to the 'users' collection
          final userRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

          //Data to save for the new user
          await userRef.set({
            'uid' : userCredential.user!.uid,
            'email' : _emailController.text.trim(),
            'name': _nameController.text.trim(), //Stored from the sign up form
            'account_balance': 0.0, //Default initial balance
            'account_number' : accountNumber, //Unique 12-digit account number
          });
        }

        _showSuccessSnackbar('Account created successfully!');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          // Record the failed attempt
          await _lockoutService.recordFailedAttempt(_emailController.text.trim());

          // Get remaining attempts
          final remainingAttempts = await _lockoutService.getRemainingAttempts(_emailController.text.trim());

          if (remainingAttempts > 0) {
            errorMessage = 'Wrong password provided. '
                'You have $remainingAttempts attempt${remainingAttempts > 1 ? 's' : ''} remaining before your account is temporarily locked.';
          } else {
            errorMessage = 'Wrong password provided. '
                'Your account has been temporarily locked for ${LoginLockoutService.lockoutDurationMinutes} minutes due to multiple failed attempts.';
            // Update UI to show lockout banner
            setState(() {
              isLockedOut = true;
              lockoutRemainingMinutes = LoginLockoutService.lockoutDurationMinutes;
            });
          }
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'invalid-credential':
          // Record the failed attempt
          await _lockoutService.recordFailedAttempt(_emailController.text.trim());

          // Get remaining attempts
          final remainingAttempts = await _lockoutService.getRemainingAttempts(_emailController.text.trim());

          if (remainingAttempts > 0) {
            errorMessage = 'Invalid email or password. '
                'You have $remainingAttempts attempt${remainingAttempts > 1 ? 's' : ''} remaining before your account is temporarily locked.';
          } else {
            errorMessage = 'Invalid email or password. '
                'Your account has been temporarily locked for ${LoginLockoutService.lockoutDurationMinutes} minutes due to multiple failed attempts.';
            // Update UI to show lockout banner
            setState(() {
              isLockedOut = true;
              lockoutRemainingMinutes = LoginLockoutService.lockoutDurationMinutes;
            });
          }
          break;
        default:
          errorMessage = e.message ?? 'An error occurred. Please try again.';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('An unexpected error occurred. Please try again');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showErrorDialog('Please enter your email address first.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSuccessSnackbar('Password reset email sent! Check your inbox.');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'No user found with this email.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send password reset email.';
      }
      _showErrorDialog(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [secondaryGreen, primaryGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 60),
                  _buildAuthCard(),
                ],
              ),
            ),
          )
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance, size: 60, color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TraVQR',
          style: TextStyle(
            color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin ? 'Welcome back!' : 'Create your account',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9), fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isLogin ? 'Sign In' : 'Sign Up',
              style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Lockout warning banner (only for login)
            if (isLogin && isLockedOut) ...[
              _buildLockoutBanner(),
              const SizedBox(height: 16),
            ],

            //Name field (only for sign up)
            if (!isLogin) ...[
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [CapitalizeWordsFormatter()],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                }
              ),
              const SizedBox(height: 16),
            ],

            //Email field
            _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  if (!value.contains('.com')) {
                  return 'Email must contain .com';
                  }
                  // Check that .com comes after @
                  final atIndex = value.indexOf('@');
                  final comIndex = value.indexOf('.com');
                  if (comIndex <= atIndex) {
                    return 'Please enter a valid email format';
                  }
                  return null;
                }
              ),
              const SizedBox(height: 16),

            //Password field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              }
            ),
            // Password strength indicator (only for signup)
            _buildPasswordStrengthIndicator(),

            // Confirm password field (only for signup)
            if (!isLogin) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                icon: Icons.lock_outline,
                isPassword: true,
                isConfirmPassword: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                }
              ),
            ],
            
            //Forgot password (only for login)
            if (isLogin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword, 
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ),
              )
            ],

            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 20),
            _buildToggleAuthMode(),
          ],
        )
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isConfirmPassword = false,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    // Determine which visibility state to use
    bool isVisible = isConfirmPassword ? isConfirmPasswordVisible : isPasswordVisible;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !isVisible,
      validator: validator,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: const TextStyle(color: primaryGreen),
        prefixIcon: Icon(icon, color: primaryGreen),
        suffixIcon: isPassword
          ? IconButton(
            onPressed: () {
              setState(() {
                if (isConfirmPassword) {
                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                } else {
                  isPasswordVisible = !isPasswordVisible;
                }
              });
            }, 
            icon: Icon(
              isVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ))
          : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, secondaryGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitForm, 
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(12),
          )
        ),
        child: isLoading
          ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
          : Text(
            isLogin ? 'Sign In' : 'Sign Up',
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
            ),
          )
        ),
    );
  }

  Widget _buildToggleAuthMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? "Don't have an account? " : "Already have an account? ",
          style: TextStyle(color: Colors.grey[700]),
        ),
        TextButton(
          onPressed: _toggleAuthMode,
          child: Text(
            isLogin ? 'Sign Up' : 'Sign In',
            style: const TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          )
        )
      ],
    );
  }

  // Lockout Banner
  Widget _buildLockoutBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_clock,
            color: Colors.red.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Locked',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Too many failed attempts. Your account has been locked for $lockoutRemainingMinutes minute${lockoutRemainingMinutes > 1 ? 's' : ''}.',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //Password Indicator 
  Widget _buildPasswordStrengthIndicator() {
    // Only show during signup and when password has content
    if (isLogin || _passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    //Determine color based on strength
    Color strengthColor;
    if (_passwordStrength <= 2) {
      strengthColor = errorRed;
    } else if (_passwordStrength <= 4) {
      strengthColor = Colors.orange;
    } else {
      strengthColor = successGreen;
    }

    double progress = _passwordStrength / 5; // Calculate progress (0.2, 0.4, 0.6, 0.8, 1.0)
    String strengthLabel = PasswordValidator.getStrengthLabel(_passwordStrength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Strength label
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              strengthLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: strengthColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Strength bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            minHeight: 6,
          ),
        ),

        // Hint text (only if not all requirements met)
        if (_passwordStrength < 5) ...[
          const SizedBox(height: 6),
          Text(
            _passwordHint,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: successGreen),
              const SizedBox(width: 4),
              Text(
                _passwordHint,
                style: const TextStyle(
                  fontSize: 11,
                  color: successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Custom TextInputFormatter to capitalize first letter of each word
class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Capitalize first letter of each word
    String capitalized = _capitalizeWords(newValue.text);

    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;

    StringBuffer result = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      if (char == ' ') {
        result.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        result.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        result.write(char);
      }
    }

    return result.toString();
  }
}