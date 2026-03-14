import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:echo_reading/screens/book_confirm_screen.dart';
import 'package:echo_reading/services/book_api_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanBookScreen extends StatefulWidget {
  const ScanBookScreen({super.key});

  @override
  State<ScanBookScreen> createState() => _ScanBookScreenState();
}

class _ScanBookScreenState extends State<ScanBookScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  final BookApiService _bookApiService = BookApiService();

  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    final isbn = _bookApiService.normalizeIsbn(raw);
    if (isbn == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未识别到有效 ISBN（10/13位）')));
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _controller.stop();
    try {
      final book = await _bookApiService.fetchByIsbn(isbn);
      if (!mounted) return;
      if (book == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未查询到该 ISBN 对应书籍')));
        await _controller.start();
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => BookConfirmScreen(book: book)),
      );

      if (!mounted) return;
      if (saved == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('扫码录入完成')));
      }
      await _controller.start();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败：$error')));
      await _controller.start();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码录入书籍')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              final isWebHttp = kIsWeb && Uri.base.scheme == 'http';
              final needHttps = isWebHttp &&
                  (error.errorCode == MobileScannerErrorCode.permissionDenied ||
                      error.errorCode == MobileScannerErrorCode.unsupported);
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_off_rounded,
                          size: 64,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          needHttps
                              ? '扫码需要 HTTPS'
                              : '相机无法使用',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          needHttps
                              ? '手机浏览器要求通过 HTTPS 访问才能使用相机。\n请用 run_all.sh（不用 HTTP=1）启动，或改用本机 localhost 测试。'
                              : error.errorDetails?.message ?? error.errorCode.message,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: EdgeInsets.all(
                ResponsiveLayout.isTablet(context) ? 20 : 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '请将书本背面的 ISBN 条形码放入取景框内',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveLayout.isTablet(context) ? 18 : 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
