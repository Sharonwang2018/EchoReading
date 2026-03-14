/// Web stub: upload from file path not supported, would need Blob/XFile
Future<String> uploadAudioFile(Object fileOrPath, {String contentType = 'audio/webm'}) async {
  throw UnsupportedError('音频上传在 Web 端暂不支持，请在移动端或桌面端使用');
}
