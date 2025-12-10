import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';

class RouteGuard {
  static Widget adminOnly(Widget child) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // CORRECCIÓN: Usar currentUser en lugar de getUsuarioActual()
        final currentUser = authService.currentUser;
        
        if (currentUser == null) {
          return LoginScreen();
        }
        
        if (!currentUser.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: Text('Acceso Denegado')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Acceso Restringido',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Solo los administradores pueden acceder a esta sección',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Volver al Menú Principal'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return child;
      },
    );
  }

  static Widget authenticatedOnly(Widget child) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // CORRECCIÓN: Usar currentUser en lugar de getUsuarioActual()
        final currentUser = authService.currentUser;
        
        if (currentUser == null) {
          return LoginScreen();
        }
        
        return child;
      },
    );
  }
}