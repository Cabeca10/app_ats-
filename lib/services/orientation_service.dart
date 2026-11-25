import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pwa_helper.dart';

/// Gerencia a orientação do aplicativo combinando a API nativa / do navegador
/// com fallback visual (RotatedBox) caso o SO/WebAPK bloqueie a rotação.
class OrientationService {
  OrientationService._();

  static final OrientationService instance = OrientationService._();

  /// Controla se o usuário solicitou manualmente modo paisagem dentro do app.
  final ValueNotifier<bool> forcedLandscapeNotifier = ValueNotifier<bool>(false);

  /// Retorna true se a tela já está em paisagem (física ou forçada).
  bool isLandscapeActive(BuildContext context) {
    if (forcedLandscapeNotifier.value) return true;
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  /// Alterna entre modo paisagem (horizontal) e modo retrato/sensor livre.
  Future<void> toggleOrientation(BuildContext context) async {
    final currentlyLandscape = isLandscapeActive(context);

    if (!currentlyLandscape) {
      forcedLandscapeNotifier.value = true;
      requestBrowserOrientation('landscape');
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (_) {}
    } else {
      forcedLandscapeNotifier.value = false;
      requestBrowserOrientation('any');
      try {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      } catch (_) {}
    }
  }
}
