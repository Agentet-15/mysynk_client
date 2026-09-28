class PairingQrData {
  const PairingQrData({
    required this.server,
    required this.pairing,
    required this.expires,
  });

  final String server;
  final String pairing;
  final DateTime expires;
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

    if (server == null ||
        server.isEmpty ||
        pairing == null ||
        pairing.isEmpty ||
        expiresRaw == null ||
        expiresRaw.isEmpty) {
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
    );
  }
}
