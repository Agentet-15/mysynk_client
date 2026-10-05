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
  static const MethodChannel _channel =
      MethodChannel('com.mysynk/saf');

  Future<SafDirectory?> pickDirectory() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'pickDirectory',
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
