class PairingQrData {
  const PairingQrData({
    required this.server,
    required this.pairing,
    required this.expires,
    required this.url,
  });

  final String server;
  final String pairing;
  final DateTime expires;
  final String url;
}

class PairingQrParser {
  static PairingQrData? parse(String rawValue) {
    final uri = Uri.tryParse(rawValue.trim());

    if (uri == null) {
      return null;
    }

    if (uri.scheme != 'mysynk' || uri.host != 'pair') {
      return null;
    }

    final server = uri.queryParameters['server']?.trim();
    final pairing = uri.queryParameters['pairing']?.trim();
    final expiresRaw = uri.queryParameters['expires']?.trim();
    final urlRaw = uri.queryParameters['url']?.trim();

    if (server == null ||
        server.isEmpty ||
        pairing == null ||
        pairing.isEmpty ||
        expiresRaw == null ||
        expiresRaw.isEmpty ||
        urlRaw == null ||
        urlRaw.isEmpty) {
      return null;
    }

    final url = Uri.tryParse(urlRaw);

    if (url == null ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty) {
      return null;
    }

    final expires = DateTime.tryParse(expiresRaw);

    if (expires == null || !expires.isAfter(DateTime.now())) {
      return null;
    }

    return PairingQrData(
      server: server,
      pairing: pairing,
      expires: expires,
      url: url.toString(),
    );
  }
}
