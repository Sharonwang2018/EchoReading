import 'dart:async';
import 'dart:io';

import 'package:echo_reading/services/page_ocr_service.dart';
import 'package:echo_reading/services/page_tts_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 拍照读页：孩子翻到哪页拍哪页，AI 识别后朗读，不存储全书，无侵权风险
/// 豆包 TTS 失败时自动降级为设备朗读，确保一定能读出
class PhotoReadPageScreen extends StatefulWidget {
  const PhotoReadPageScreen({super.key});

  @override
  State<PhotoReadPageScreen> createState() => _PhotoReadPageScreenState();
}

class _PhotoReadPageScreenState extends State<PhotoReadPageScreen> {
  final PageOcrService _ocrService = PageOcrService();
  final PageTtsService _ttsService = PageTtsService();
  final ImagePicker _picker = ImagePicker();

  File? _photoFile;
  String? _extractedText;
  bool _isProcessing = false;
  bool _isPlaying = false;
  String _statusText = '';
  String? _lastError;

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  Future<void> _takePhoto() async {
    if (_isProcessing) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _photoFile = File(photo.path);
        _extractedText = null;
        _lastError = null;
        _isProcessing = true;
      });

      _setStatus('识别中...');
      final bytes = await File(photo.path).readAsBytes();

      String text;
      try {
        text = await _ocrService.extractTextFromImage(bytes);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _lastError = '识别失败，请重拍或确保光线充足';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('识别失败：$e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _takePhoto,
            ),
          ),
        );
        return;
      }

      final t = text.trim();
      if (t.isEmpty) {
        if (!mounted) return;
        setState(() {
          _lastError = '未识别到文字，请重拍或调整角度';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未识别到文字，请重拍或确保页面清晰'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _extractedText = t;
        _statusText = '朗读中...';
        _isPlaying = true;
      });

      try {
        await _ttsService.speak(t);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('朗读失败：$e')),
        );
      }

      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isProcessing = false;
        _statusText = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = '出错了，请重试';
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('处理失败：$error'),
          action: SnackBarAction(label: '重试', onPressed: _takePhoto),
        ),
      );
    }
  }

  Future<void> _playAgain() async {
    if (_extractedText == null || _extractedText!.trim().isEmpty) return;
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
      _statusText = '朗读中...';
    });

    try {
      await _ttsService.speak(_extractedText!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败：$e')),
      );
    }

    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _statusText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照读页'),
      ),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '翻到哪页拍哪页，AI 读给你听',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '不存储全书，仅识别当前页并朗读。本地 PaddleOCR 识别，置信度不足时自动用 Azure 补偿；朗读失败时用设备 TTS。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_photoFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _photoFile!,
                    fit: BoxFit.contain,
                    height: ResponsiveLayout.isTablet(context) ? 320 : 240,
                  ),
                )
              else
                Container(
                  height: ResponsiveLayout.isTablet(context) ? 280 : 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击下方按钮拍摄当前页',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_statusText),
                  ],
                ),
              ],
              if (_lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _lastError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _takePhoto,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(
                  _isProcessing ? '识别并朗读中...' : '拍摄当前页',
                ),
              ),
              if (_extractedText != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '识别内容',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (!_isProcessing)
                              FilledButton.tonalIcon(
                                onPressed: _isPlaying ? null : _playAgain,
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.volume_up_rounded
                                      : Icons.play_circle_outline_rounded,
                                ),
                                label: Text(_isPlaying ? '播放中' : '再次播放'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_extractedText!),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
