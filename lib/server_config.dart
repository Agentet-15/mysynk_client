import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const String _serverUrlKey = 'mysynk_server_url';

  static const String defaultServerUrl =
      'http://192.168.101.104:3000';

  static Future<String> getServerUrl() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(_serverUrlKey) ??
        defaultServerUrl;
  }

  static Future<void> setServerUrl(String url) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _serverUrlKey,
      url.trim().replaceFirst(RegExp(r'/$'), ''),
    );
  }
}
