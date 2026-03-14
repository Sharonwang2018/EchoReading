import 'dart:typed_data';

/// Web：不支持本地文件路径，仅 blob/http
Future<Uint8List> readAudioBytes(String path) async {
  throw UnimplementedError('本地文件路径仅支持移动端');
}
