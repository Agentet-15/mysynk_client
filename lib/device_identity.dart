import 'package:flutter/services.dart';

class DeviceIdentity {
  static const MethodChannel _channel =
      MethodChannel('com.example.mysynk/device_identity');

  static Future<String> getAndroidId() async {
    final value = await _channel.invokeMethod<String>('getAndroidId');

    if (value == null || value.trim().isEmpty) {
      throw Exception('No se pudo obtener la identidad del dispositivo');
    }

    return value.trim();
  }
}
