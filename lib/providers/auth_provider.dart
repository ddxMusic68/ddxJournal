import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _pinIsSet = false;
  bool _isLoading = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get pinIsSet => _pinIsSet;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _pinIsSet = await _authService.isPinSet();
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    _isLoading = true;
    notifyListeners();
    final valid = await _authService.verifyPin(pin);
    if (valid) _isAuthenticated = true;
    _isLoading = false;
    notifyListeners();
    return valid;
  }

  Future<void> setPin(String pin) async {
    await _authService.setPin(pin);
    _pinIsSet = true;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> clearPin() async {
    await _authService.clearPin();
    _pinIsSet = false;
    _isAuthenticated = false;
    notifyListeners();
  }

  void lock() {
    _isAuthenticated = false;
    notifyListeners();
  }
}
