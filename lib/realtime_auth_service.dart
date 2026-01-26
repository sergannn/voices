import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class RealtimeAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final RealtimeChannel _userChannel;
  late final StreamController<Map<String, dynamic>?> _streamController;

  RealtimeAuthService() {
    _userChannel = _supabase.channel('users_channel');
    _streamController = StreamController<Map<String, dynamic>?>.broadcast();
  }

  // Подписка на изменения данных пользователя
  Stream<Map<String, dynamic>?> subscribeToUserData() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('Пользователь не авторизован');
      return Stream.value(null);
    }

    // Настраиваем подписку на изменения в таблице
    _userChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Авторизация / Регистрация',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'email',
        value: user.email!,
      ),
      callback: (payload) {
        print('Realtime обновление пользователя: $payload');
        _handleRealtimeUpdate(payload);
      },
    ).subscribe();

    // Первоначальная загрузка данных
    _loadInitialData();

    return _streamController.stream;
  }

  // Обработка realtime обновлений
void _handleRealtimeUpdate(PostgresChangePayload payload) {
  print('Realtime событие: ${payload.eventType}');
  
  final eventType = payload.eventType;
  
  // Используем константы PostgresChangeEvent для сравнения
  if (eventType == PostgresChangeEvent.insert || eventType == PostgresChangeEvent.update) {
    final newRecord = payload.newRecord;
    // Убрана ненужная проверка на null, так как newRecord не может быть null для INSERT/UPDATE
    print('Новые данные: $newRecord');
    _streamController.add(Map<String, dynamic>.from(newRecord));
  } else if (eventType == PostgresChangeEvent.delete) {
    print('Данные удалены');
    _streamController.add(null);
  } else {
    print('Неизвестное событие: $eventType');
  }
}

  // Загрузка начальных данных
  void _loadInitialData() async {
    try {
      final userData = await getCurrentUserData();
      if (userData != null) {
        _streamController.add(userData);
      }
    } catch (e) {
      print('Ошибка загрузки начальных данных: $e');
      _streamController.addError(e);
    }
  }

  // Получить текущие данные пользователя
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('Авторизация / Регистрация')
          .select()
          .eq('email', user.email!)
          .single();

      print('Данные пользователя получены (realtime): $response');
      return response;
    } catch (e) {
      print('Ошибка получения данных пользователя (realtime): $e');
      return null;
    }
  }

  // Альтернативный метод подписки с более простой настройкой
  Stream<Map<String, dynamic>?> subscribeToUserDataSimple() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    // Создаем stream из supabase realtime
    return _supabase
        .from('Авторизация / Регистрация')
        .stream(primaryKey: ['email'])
        .eq('email', user.email!)
        .map((event) {
          if (event.isNotEmpty) {
            return event.first;
          }
          return null;
        });
  }

  // Подписка на все изменения в таблице (для админа)
  Stream<List<Map<String, dynamic>>> subscribeToAllUsers() {
    return _supabase
        .from('Авторизация / Регистрация')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(10);
  }

  // Отключить подписку
  void dispose() {
    _supabase.removeChannel(_userChannel);
    _streamController.close();
    print('Realtime подписка отключена');
  }

  // Простой метод для тестирования realtime
  void testRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    print('Тестирование realtime подписки...');
    
    _userChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Авторизация / Регистрация',
      callback: (payload) {
        print('Тестовое событие: ${payload.eventType}');
        print('Старые данные: ${payload.oldRecord}');
        print('Новые данные: ${payload.newRecord}');
      },
    ).subscribe();
  }
}