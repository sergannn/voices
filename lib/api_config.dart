/// Базовые адреса API для приложения Voices.
/// Сервер: music.panfilius.ru
class ApiConfig {
  ApiConfig._();

  static const String serverBase = 'https://music.panfilius.ru';

  /// Сохранение записи (Laravel).
  static String get newRecordUrl => '$serverBase/api/newRecord';
}
