import 'package:shared_preferences/shared_preferences.dart';

/// Identidad y token del dispositivo devueltos por
/// `/api/v1/pairing/authorize`.
///
/// El token se entrega una sola vez, así que debe persistirse en cuanto
/// se completa el emparejamiento. Solo se guarda la identidad pública;
/// el servidor almacena únicamente el hash SHA-256 del token.
class DeviceAuth {
  static const String deviceIdKey = 'mysynk_device_id';
  static const String tokenKey = 'mysynk_device_token';
  static const String nameKey = 'mysynk_device_name';

  static final RegExp _tokenPattern = RegExp(r'^[a-f0-9]{64}$');

  static bool isValidToken(String token) =>
      _tokenPattern.hasMatch(token.trim());

  static Future<String?> getDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(deviceIdKey)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  static Future<String?> getAccessToken() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(tokenKey)?.trim();

    if (value == null || value.isEmpty || !isValidToken(value)) {
      return null;
    }

    return value;
  }

  /// Nombre legible del dispositivo, usado en la ruta de respaldo.
  static Future<String?> getName() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(nameKey)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  static Future<void> saveName(String name) async {
    final normalized = normalizeDeviceName(name);

    if (normalized.isEmpty) {
      throw ArgumentError('El nombre del dispositivo está vacío.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(nameKey, normalized);
  }

  /// Normaliza un nombre para usarlo como segmento de ruta.
  static String normalizeDeviceName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }

  static Future<void> save({
    required String deviceId,
    required String accessToken,
    String? name,
  }) async {
    final normalizedId = deviceId.trim();
    final normalizedToken = accessToken.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('El identificador del dispositivo está vacío.');
    }

    if (!isValidToken(normalizedToken)) {
      throw ArgumentError('El token del dispositivo no es válido.');
    }

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(deviceIdKey, normalizedId);
    await preferences.setString(tokenKey, normalizedToken);

    if (name != null && normalizeDeviceName(name).isNotEmpty) {
      await preferences.setString(nameKey, normalizeDeviceName(name));
    }
  }

  /// Llamar cuando el servidor responda `403 DEVICE_NOT_ACTIVE`.
  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(deviceIdKey);
    await preferences.remove(tokenKey);
  }
}
