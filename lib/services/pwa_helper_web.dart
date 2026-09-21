import 'dart:js_interop';

@JS('promptPwaInstallation')
external void _promptPwaInstallation();

@JS('pwaInstallPrompt')
external JSAny? get _pwaInstallPrompt;

void promptPwaInstallation() {
  try {
    _promptPwaInstallation();
  } catch (_) {}
}

bool isPwaInstallAvailable() {
  try {
    return _pwaInstallPrompt != null;
  } catch (_) {
    return false;
  }
}
