import 'dart:js_interop';

@JS('promptPwaInstallation')
external bool _promptPwaInstallation();

@JS('pwaInstallPrompt')
external JSAny? get _pwaInstallPrompt;

@JS('isRunningStandalone')
external bool _isRunningStandalone();

@JS('requestBrowserOrientation')
external void _requestBrowserOrientation(JSString mode);

bool promptPwaInstallation() {
  try {
    return _promptPwaInstallation();
  } catch (_) {
    return false;
  }
}

bool isPwaInstallAvailable() {
  try {
    return _pwaInstallPrompt != null;
  } catch (_) {
    return false;
  }
}

bool isRunningStandalone() {
  try {
    return _isRunningStandalone();
  } catch (_) {
    return false;
  }
}

void requestBrowserOrientation(String mode) {
  try {
    _requestBrowserOrientation(mode.toJS);
  } catch (_) {}
}
