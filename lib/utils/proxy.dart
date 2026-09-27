import 'package:flutter/services.dart';
import 'package:universal_io/io.dart' show Platform;

Future<String?> getGitProxy(String? configuredProxy) async {
  if (configuredProxy != null && configuredProxy.trim().isNotEmpty) {
    return configuredProxy.trim();
  }

  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('gitjournal.io/git');
      final proxy = await channel.invokeMethod<String>('getProxy');
      if (proxy != null && proxy.isNotEmpty) {
        if (!proxy.contains('://')) {
          return 'http://$proxy';
        }
        return proxy;
      }
    } catch (_) {}
  }

  return null;
}