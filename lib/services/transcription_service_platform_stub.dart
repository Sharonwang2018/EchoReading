/// Web 端：无本地 Whisper，始终用 API
bool get canUseLocal => false;

Future<String?> transcribeWithLocal(String audioPath) async => null;
