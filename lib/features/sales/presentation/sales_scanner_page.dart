import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SalesScannerPage extends StatefulWidget {
  const SalesScannerPage({super.key});

  @override
  State<SalesScannerPage> createState() => _SalesScannerPageState();
}

class _SalesScannerPageState extends State<SalesScannerPage> {
  final _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_hasScanned) {
      return;
    }

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (code == null || code.isEmpty) {
      return;
    }

    _hasScanned = true;
    _controller.stop();
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barang'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return _ScannerError(message: error.toString());
            },
          ),
          const _ScannerOverlay(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              color: Colors.black.withValues(alpha: 0.58),
              child: const Text(
                'Arahkan kamera ke QR Code atau barcode barang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 46,
            ),
            const SizedBox(height: 14),
            const Text(
              'Kamera tidak tersedia',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Input Manual'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
        ),
        child: Stack(
          children: const [
            _Corner(alignment: Alignment.topLeft),
            _Corner(alignment: Alignment.topRight),
            _Corner(alignment: Alignment.bottomLeft),
            _Corner(alignment: Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(color: Color(0xFF2563EB), width: 5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
