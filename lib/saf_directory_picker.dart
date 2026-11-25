import 'package:flutter/services.dart';

class SafDirectory {
  const SafDirectory({
    required this.uri,
    required this.name,
  });

  final String uri;
  final String name;
}

class SafDirectoryPicker {
  // Debe coincidir con SAF_CHANNEL en MainActivity.kt.
  static const MethodChannel channel =
      MethodChannel('com.example.mysynk/saf');

  /// Comprueba que Android todavía permite acceder a la carpeta.
  static Future<bool> checkDirectory(String uri) async {
    try {
      final value = await channel.invokeMethod<bool>(
        'checkDirectory',
        {'root': uri},
      );
      return value == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Construye la URI SAF de una carpeta conocida del almacenamiento
  /// interno, por ejemplo `DCIM/Camera`.
  static String uriForInternalFolder(String relativePath) {
    final encoded = Uri.encodeComponent(
      relativePath.replaceAll(r'\', '/').replaceAll(RegExp(r'^/+'), ''),
    );
    return 'content://com.android.externalstorage.documents/tree/'
        'primary%3A$encoded';
  }

  /// Abre el explorador de Android. Si se indica [initialUri], el
  /// explorador se abre directamente en esa carpeta.
  Future<SafDirectory?> pickDirectory({String? initialUri}) async {
    final result = await channel.invokeMethod<Map<Object?, Object?>>(
      'pickDirectory',
      {'initialUri': initialUri},
    );

    if (result == null) {
      return null;
    }

    final uri = result['uri'] as String?;
    final name = result['name'] as String?;

    if (uri == null || uri.isEmpty) {
      throw Exception('Android no devolvió el URI de la carpeta.');
    }

    return SafDirectory(
      uri: uri,
      name: name ?? '',
    );
  }
}
