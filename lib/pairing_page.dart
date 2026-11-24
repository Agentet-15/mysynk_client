import 'package:flutter/material.dart';

import 'device_auth.dart';
import 'device_identity.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'mysynk_api.dart';
import 'pairing_parser.dart';
import 'server_config.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  PairingQrData? _pairing;
  bool _handledScan = false;
  bool _connecting = false;
  String? _error;

  void _handleBarcode(BarcodeCapture capture) {
    if (_handledScan || _connecting) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();

      if (value == null || value.isEmpty) {
        continue;
      }

      final pairing = PairingQrParser.parse(value);

      if (pairing == null) {
        continue;
      }

      setState(() {
        _pairing = pairing;
        _handledScan = true;
        _error = null;
      });

      _controller.stop();
      return;
    }
  }

  Future<void> _connect() async {
    final pairing = _pairing;

    if (pairing == null || _connecting) {
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      debugPrint('MYSYNK: iniciando conexión...');
      final androidId = await DeviceIdentity.getAndroidId();
      debugPrint('MYSYNK: ANDROID_ID obtenido');
      debugPrint('MYSYNK: androidId = $androidId');

      final api = MySynkApi(
        baseUrl: pairing.url,
      );

      debugPrint('MYSYNK: enviando autorización de pairing...');
      final pairingResult = await api.authorizePairing(
        token: pairing.pairing,
        name: 'Mi dispositivo Android',
        type: 'android',
        platformIdentifier: androidId,
      );

      final device = pairingResult['device'];
      final deviceId =
          device is Map ? device['id'] : null;

      if (deviceId is! String || deviceId.trim().isEmpty) {
        throw Exception(
          'El servidor no devolvió el identificador del dispositivo',
        );
      }

      final accessToken = pairingResult['accessToken'];

      if (accessToken is! String ||
          !DeviceAuth.isValidToken(accessToken)) {
        throw Exception(
          'El servidor no devolvió un token de dispositivo válido. '
          'Vuelve a generar el QR e inténtalo de nuevo.',
        );
      }

      await DeviceAuth.save(
        deviceId: deviceId.trim(),
        accessToken: accessToken.trim(),
      );

      debugPrint('MYSYNK: pairing completado y token guardado');

      await ServerConfig.setServerUrl(pairing.url);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connecting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scanAgain() {
    setState(() {
      _pairing = null;
      _handledScan = false;
      _error = null;
    });

    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairing = _pairing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar servidor'),
      ),
      body: pairing == null
          ? Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: _handleBarcode,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Text(
                    'Apunta la cámara al código QR mostrado por MySynk.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_done_rounded,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Servidor MySynk encontrado',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _PairingInfoRow(
                    label: 'Servidor',
                    value: pairing.server,
                  ),
                  const SizedBox(height: 16),
                  _PairingInfoRow(
                    label: 'Dirección',
                    value: pairing.url,
                  ),
                  const SizedBox(height: 16),
                  _PairingInfoRow(
                    label: 'Expira',
                    value: pairing.expires.toLocal().toString(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: _connecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _connecting ? 'Conectando...' : 'Conectar',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _connecting ? null : _scanAgain,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear de nuevo'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PairingInfoRow extends StatelessWidget {
  const _PairingInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
