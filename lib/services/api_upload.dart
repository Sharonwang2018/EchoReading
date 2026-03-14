import 'api_upload_io.dart' if (dart.library.html) 'api_upload_web.dart' as impl;

Future<String> uploadAudioFile(Object fileOrPath, {String contentType = 'audio/webm'}) {
  return impl.uploadAudioFile(fileOrPath, contentType: contentType);
}
