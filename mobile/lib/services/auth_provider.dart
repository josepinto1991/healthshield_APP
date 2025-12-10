import 'package:flutter/material.dart';
import '../models/usuario.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _currentUser;
  
  Usuario? get currentUser => _currentUser;
  
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isProfessional => _currentUser?.isProfessionalUser ?? false;
  bool get isRegularUser => _currentUser?.isUser ?? true;
  
  void login(Usuario user) {
    _currentUser = user;
    notifyListeners();
  }
  
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
  
  bool hasPermission(String requiredRole) {
    if (_currentUser == null) return false;
    
    switch (requiredRole) {
      case 'admin':
        return _currentUser!.isAdmin;
      case 'professional':
        return _currentUser!.isProfessionalUser || _currentUser!.isAdmin;
      case 'user':
        return true;
      default:
        return false;
    }
  }
}