import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pairing_parser.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final MobileScannerController _controller = MobileScannerController();

  PairingQrData? _pairing;
  bool _handledScan = false;

  void _handleBarcode(BarcodeCapture capture) {
    if (_handledScan) {
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
      });

      _controller.stop();
      return;
    }
  }

  void _scanAgain() {
    setState(() {
      _pairing = null;
      _handledScan = false;
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
        title: const Text('Emparejar servidor'),
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
                    Icons.verified_rounded,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'QR de MySynk reconocido',
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
                    label: 'Expira',
                    value: pairing.expires.toLocal().toString(),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _scanAgain,
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
