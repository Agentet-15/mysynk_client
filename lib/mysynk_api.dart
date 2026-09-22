import 'dart:convert';

import 'package:http/http.dart' as http;

class MySynkApi {
  MySynkApi({
    required this.baseUrl,
  });

  final String baseUrl;

  Future<bool> testConnection() async {
    final uri = Uri.parse('$baseUrl/api/v1/files');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    return data is Map<String, dynamic> &&
        data.containsKey('items');
  }

  Future<List<Map<String, dynamic>>> listFiles(String path) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/files?path=${Uri.encodeComponent(path)}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al consultar los archivos');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final items = data['items'];

    if (items is! List) {
      throw Exception(
        'La respuesta no contiene una lista de archivos',
      );
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final uri = Uri.parse('$baseUrl/api/v1/devices');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al consultar los dispositivos');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final devices = data['devices'];

    if (devices is! List) {
      throw Exception(
        'La respuesta no contiene una lista de dispositivos',
      );
    }

    return devices
        .whereType<Map>()
        .map((device) => Map<String, dynamic>.from(device))
        .toList();
  }
}
