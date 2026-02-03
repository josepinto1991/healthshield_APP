import 'package:flutter/material.dart';

class KeyboardUtils {
  // Obtener padding inferior seguro para teclado
  static double getBottomPadding(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return bottomPadding + bottomInset + 20;
  }
  
  // Obtener padding completo de pantalla
  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.only(
      bottom: getBottomPadding(context),
      left: 16,
      right: 16,
      top: 16,
    );
  }
  
  // Obtener margin inferior para botones
  static EdgeInsets getButtonMargin(BuildContext context) {
    return EdgeInsets.only(
      bottom: getBottomPadding(context) + 24,
    );
  }
  
  // Verificar si el teclado está visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
}