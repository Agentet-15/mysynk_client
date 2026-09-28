import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const String _serverUrlKey = 'mysynk_server_url';

  static Future<String?> getServerUrl() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(_serverUrlKey);
  }

  static Future<void> setServerUrl(String url) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _serverUrlKey,
      url.trim().replaceFirst(RegExp(r'/$'), ''),
    );
  }

  static Future<void> clearServerUrl() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_serverUrlKey);
  }
}
