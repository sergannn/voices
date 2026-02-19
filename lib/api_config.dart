/// Базовые адреса API для приложения Voices.
/// Сервер: music.panfilius.ru
/// Voicegram — Python-сервис на порту 8002 (без прокси).
class ApiConfig {
  ApiConfig._();

  static const String serverBase = 'https://music.panfilius.ru';
  /// Прямое подключение к voicegram (uvicorn на 8002). Порт должен быть открыт.
  static const String voicegramApiBase = 'http://music.panfilius.ru:8002';

  /// Сохранение записи (Laravel).
  static String get newRecordUrl => '$serverBase/api/newRecord';

  /// Распознавание аудио (Voicegram).
  static String get transcribeUrl => '$voicegramApiBase/transcribe';
}
