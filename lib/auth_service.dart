import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // SELECT - Получить данные пользователя
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Пользователь не авторизован');
        return null;
      }

      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('email', user.email!)
          .single();

      print('Данные пользователя получены: $response');
      return response;
    } catch (e) {
      print('Ошибка получения данных пользователя: $e');
      return null;
    }
  }

  // INSERT - Создать запись пользователя
  Future<bool> createUserData({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String phoneNumber,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Пользователь не авторизован');
        return false;
      }

      final phoneNumberInt = int.tryParse(phoneNumber) ?? 0;

      final response = await _supabase.from('user_profiles').insert({
        'id': user.id, // Используем ID из auth
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'phone_number': phoneNumberInt,
        'is_active': 1,
      });

      print('Данные пользователя созданы: $response');
      return true;
    } catch (e) {
      print('Ошибка создания данных пользователя: $e');
      return false;
    }
  }

  // UPDATE - Обновить данные пользователя
  Future<bool> updateUserData({
    String? username,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? phoneNumber,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Пользователь не авторизован');
        return false;
      }

      final updateData = <String, dynamic>{};
      
      _addIfNotNull(updateData, 'username', username);
      _addIfNotNull(updateData, 'first_name', firstName);
      _addIfNotNull(updateData, 'last_name', lastName);
      _addIfNotNull(updateData, 'date_of_birth', dateOfBirth);
      
      if (phoneNumber != null) {
        updateData['phone_number'] = int.tryParse(phoneNumber) ?? 0;
      }

      if (updateData.isEmpty) {
        print('Нет данных для обновления');
        return false;
      }

      final response = await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('email', user.email!);

      print('Данные пользователя обновлены: $response');
      return true;
    } catch (e) {
      print('Ошибка обновления данных пользователя: $e');
      return false;
    }
  }

  // DELETE - Удалить данные пользователя
  Future<bool> deleteUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Пользователь не авторизован');
        return false;
      }

      final response = await _supabase
          .from('user_profiles')
          .delete()
          .eq('email', user.email!);

      print('Данные пользователя удалены: $response');
      return true;
    } catch (e) {
      print('Ошибка удаления данных пользователя: $e');
      return false;
    }
  }

  // SELECT всех пользователей (для админа)
  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      print('Получено пользователей: ${response.length}');
      return response;
    } catch (e) {
      print('Ошибка получения списка пользователей: $e');
      return [];
    }
  }

  // Получить данные пользователя по ID
  Future<Map<String, dynamic>?> getUserDataById(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();

      print('Данные пользователя по ID получены: $response');
      return response;
    } catch (e) {
      print('Ошибка получения данных пользователя по ID: $e');
      return null;
    }
  }

  // Проверить существование пользователя
  Future<bool> checkUserExists(String email) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('email', email);

      print('Проверка существования пользователя: ${response.isNotEmpty}');
      return response.isNotEmpty;
    } catch (e) {
      print('Ошибка проверки существования пользователя: $e');
      return false;
    }
  }

  // Создать профиль при регистрации
  Future<bool> createProfileAfterSignUp(User user, {
    String username = '',
    String firstName = '',
    String lastName = '',
    String dateOfBirth = '',
    String phoneNumber = '',
  }) async {
    try {
      final phoneNumberInt = int.tryParse(phoneNumber) ?? 0;

      final response = await _supabase.from('user_profiles').insert({
        'id': user.id,
        'email': user.email!,
        'username': username.isNotEmpty ? username : user.email!.split('@').first,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'phone_number': phoneNumberInt,
        'is_active': 1,
      });

      print('Профиль создан после регистрации: $response');
      return true;
    } catch (e) {
      print('Ошибка создания профиля после регистрации: $e');
      return false;
    }
  }

  // Вспомогательный метод для безопасного добавления значений
  void _addIfNotNull(Map<String, dynamic> map, String key, String? value) {
    if (value != null && value.isNotEmpty) {
      map[key] = value;
    }
  }

  // Проверить статус авторизации
  bool isUserLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  // Получить текущего пользователя
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }
}