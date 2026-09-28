import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final MobileScannerController _controller = MobileScannerController();

  String? _scannedValue;
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

      setState(() {
        _scannedValue = value;
        _handledScan = true;
      });

      _controller.stop();
      return;
    }
  }

  void _scanAgain() {
    setState(() {
      _scannedValue = null;
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
    final scannedValue = _scannedValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emparejar servidor'),
      ),
      body: scannedValue == null
          ? Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(
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
                    Icons.qr_code_2,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Código QR detectado',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(scannedValue),
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
