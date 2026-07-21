import 'package:flutter/material.dart';
import 'constants.dart';

class PasswordProvider extends ChangeNotifier {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  bool verifyPassword(String password) {
    if (password == AppConstants.defaultPassword) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void reset() {
    _isAuthenticated = false;
    notifyListeners();
  }
}
