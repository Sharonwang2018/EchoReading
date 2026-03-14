import 'dart:io';

String getRecordingPath() =>
    '${Directory.systemTemp.path}/echo_reading_${DateTime.now().millisecondsSinceEpoch}.m4a';
