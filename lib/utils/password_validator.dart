//Password Strength Indicator & Validator

class PasswordValidator {
  // RegEx patterns for validation
  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp _numberRegex = RegExp(r'[0-9]');
  static final RegExp _symbolRegex = RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]');
  static const int _minLength = 8;

  /// Checks if password has at least 8 characters
  static bool hasMinLength(String password) {
    return password.length >= _minLength;
  }

  /// Checks if password contains at least one uppercase letter
  static bool hasUppercase(String password) {
    return _uppercaseRegex.hasMatch(password);
  }

  /// Checks if password contains at least one lowercase letter
  static bool hasLowercase(String password) {
    return _lowercaseRegex.hasMatch(password);
  }

  /// Checks if password contains at least one number
  static bool hasNumber(String password) {
    return _numberRegex.hasMatch(password);
  }

  /// Checks if password contains at least one special character
  static bool hasSymbol(String password) {
    return _symbolRegex.hasMatch(password);
  }

  /// Returns a map of all password requirements and whether they are met
  static Map<String, bool> getRequirements(String password) {
    return {
      'length': hasMinLength(password),
      'uppercase': hasUppercase(password),
      'lowercase': hasLowercase(password),
      'number': hasNumber(password),
      'symbol': hasSymbol(password),
    };
  }

  /// Calculates password strength score (0-5)
  /// Returns the number of requirements met
  static int getStrengthScore(String password) {
    int score = 0;
    if (hasMinLength(password)) score++;
    if (hasUppercase(password)) score++;
    if (hasLowercase(password)) score++;
    if (hasNumber(password)) score++;
    if (hasSymbol(password)) score++;
    return score;
  }

  /// Returns a readable list of missing requirements
  static String getMissingRequirements(String password) {
    List<String> missing = [];

    if (!hasMinLength(password)) {
      int needed = _minLength - password.length;
      missing.add('$needed more character${needed > 1 ? 's' : ''}');
    }
    if (!hasUppercase(password)) {
      missing.add('uppercase letter');
    }
    if (!hasLowercase(password)) {
      missing.add('lowercase letter');
    }
    if (!hasNumber(password)) {
      missing.add('number');
    }
    if (!hasSymbol(password)) {
      missing.add('special character');
    }

    if (missing.isEmpty) {
      return 'Strong password!';
    }
    return 'Add: ${missing.join(', ')}';
  }

  /// Validates password and returns an error message if invalid
  /// Returns null if password meets all requirements
  static String? validate(String password) {
    if (password.isEmpty) {
      return 'Please enter a password';
    }
    if (!hasMinLength(password)) {
      return 'Password must be at least $_minLength characters';
    }
    if (!hasUppercase(password)) {
      return 'Password must contain an uppercase letter';
    }
    if (!hasLowercase(password)) {
      return 'Password must contain a lowercase letter';
    }
    if (!hasNumber(password)) {
      return 'Password must contain a number';
    }
    if (!hasSymbol(password)) {
      return 'Password must contain a special character';
    }
    return null; // Password is valid
  }

  /// Returns strength label based on score
  static String getStrengthLabel(int score) {
    if (score <= 2) return 'Weak';
    if (score <= 4) return 'Medium';
    return 'Strong'; // score == 5
  }
}
