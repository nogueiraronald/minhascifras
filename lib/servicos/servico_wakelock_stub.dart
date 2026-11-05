import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('minhascifras/wakelock');

Future<void> definirWakeLock(bool ativo) async {
  try {
    await _channel.invokeMethod<void>('setWakeLock', {'enable': ativo});
  } catch (_) {
    // Ignora silenciosamente em ambientes de teste ou plataformas sem canal nativo
  }
}

