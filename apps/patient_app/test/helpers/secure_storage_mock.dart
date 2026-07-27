import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// AuthNotifier's constructor unconditionally reads SecureStorage on
/// construction (there's no way to skip it via subclassing — it happens in
/// the base class's own constructor body). Any widget test that touches
/// authProvider needs this plugin channel mocked, or the read throws
/// MissingPluginException with no platform binding registered.
///
/// Call this once in a `setUp` before any test that builds a widget tree
/// reading `authProvider`.
void mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'read':
        return null;
      case 'readAll':
        return <String, String>{};
      case 'containsKey':
        return false;
      case 'isProtectedDataAvailable':
        return true;
      case 'write':
      case 'delete':
      case 'deleteAll':
        return null;
      default:
        return null;
    }
  });
}
