import 'package:flutter/services.dart';

/// Datos legibles del dispositivo Android.
class DeviceInfo {
  static const MethodChannel _channel =
      MethodChannel('com.example.mysynk/device_identity');

  /// Devuelve algo como "Motorola razr 60" o "Samsung Galaxy S24".
  static Future<String?> getLabel() async {
    try {
      final value = await _channel.invokeMethod<String>('getDeviceName');

      if (value == null || value.trim().isEmpty) {
        return null;
      }

      return value.trim().replaceAll(RegExp(r'\s+'), ' ');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
