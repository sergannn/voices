import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show User;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'login.dart';
import 'register.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  await Supabase.initialize(
    url: 'https://gxuotdmumaqjjktuarst.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4dW90ZG11bWFxamprdHVhcnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2ODc2NDUsImV4cCI6MjA3ODI2MzY0NX0.VZ775ddj_J0Ji5eGoN4HmbkuunZL6WbTA3IXHvxWOho',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const Login(),
        '/register': (context) => const Register(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  supabase.User? user; // Supabase User
  User? _firebaseUser; // Firebase User
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getAuthState();
    
    // Слушаем изменения в Firebase Auth
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        _firebaseUser = user;
        _isLoading = false;
      });
    });
    
    // Также слушаем Supabase для совместимости
    _supabase.auth.onAuthStateChange.listen((AuthState data) {
      final session = data.session;
      setState(() {
        user = session?.user;
        _isLoading = false;
      });
    });
  }

  void _getAuthState() async {
    // Проверяем Firebase Auth (приоритет)
    final firebaseCurrentUser = _auth.currentUser;
    // Также проверяем Supabase для совместимости
    final supabaseCurrentUser = _supabase.auth.currentUser;
    
    setState(() {
      _firebaseUser = firebaseCurrentUser;
      user = supabaseCurrentUser;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Проверяем Firebase Auth (приоритет) или Supabase
    if (_firebaseUser == null && user == null) {
      return const Login();
    } else {
      return const MainPage();
    }
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _supabase = Supabase.instance.client;
  final _audioRecorder = AudioRecorder();
  String _recognizedText = '';
  bool _isRecording = false;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _savedRecords = [];
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _loadSavedRecords();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // Загрузка сохраненных записей
  Future<void> _loadSavedRecords() async {
    try {
      final response = await _supabase
          .from('audio_records')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _savedRecords = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки записей: $e')),
        );
      }
    }
  }

  // Функция для начала записи
  void _startRecording() async {
    try {
      // Проверяем разрешение на запись
      if (await _audioRecorder.hasPermission()) {
        // Получаем директорию для сохранения файлов
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/recording_$timestamp.m4a';
        
        // Начинаем запись
        await _audioRecorder.start(
          const RecordConfig(),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recognizedText = '';
          _currentRecordingPath = filePath;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Необходимо разрешение на запись аудио')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка начала записи: $e')),
        );
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  // Функция для остановки записи и расшифровки
  void _stopRecordingAndRecognize() async {
    try {
      // Останавливаем запись и получаем путь к файлу
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      if (path != null && path.isNotEmpty) {
        // Проверяем, что файл существует
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          
          // Имитация распознавания речи (здесь можно добавить реальное распознавание)
          await Future.delayed(const Duration(seconds: 2));
          
          // Пример распознанного текста
          final sampleTexts = [
            'Это пример распознанного текста из аудиозаписи. Файл сохранен: ${file.path}',
            'Сегодня прекрасная погода для прогулки в парке. Солнце светит ярко, птицы поют свои песни. Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB',
            'Технологии искусственного интеллекта стремительно развиваются и меняют нашу жизнь. Запись сохранена успешно.',
            'Для успешного выполнения задачи необходимо тщательное планирование и последовательное выполнение этапов. Аудио файл готов.'
          ];
          
          final randomText = sampleTexts[DateTime.now().millisecondsSinceEpoch % sampleTexts.length];
          
          setState(() {
            _recognizedText = randomText;
            _isProcessing = false;
            _currentRecordingPath = path;
          });
        } else {
          throw Exception('Файл записи не найден');
        }
      } else {
        throw Exception('Не удалось получить путь к файлу записи');
      }
    } catch (e) {
      setState(() {
        _recognizedText = 'Ошибка при остановке записи: $e';
        _isProcessing = false;
        _isRecording = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  // Сохранение распознанного текста и файла
  Future<void> _saveRecord() async {
    if (_recognizedText.isEmpty || _currentRecordingPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных для сохранения')),
        );
      }
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Проверяем, что файл существует
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        throw Exception('Аудио файл не найден');
      }

      // Сохраняем информацию о записи в базу данных
      final record = {
        'user_id': _supabase.auth.currentUser!.id,
        'text': _recognizedText,
        'file_path': _currentRecordingPath,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('audio_records')
          .insert(record)
          .select();

      if (response.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Запись успешно сохранена! Файл: ${file.path}'),
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Обновляем список записей
          await _loadSavedRecords();
          
          // Очищаем текущий текст и путь
          setState(() {
            _recognizedText = '';
            _currentRecordingPath = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Удаление записи
  Future<void> _deleteRecord(String recordId) async {
    try {
      await _supabase
          .from('audio_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', _supabase.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись удалена')),
        );
        
        await _loadSavedRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная страница'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Выход из Firebase Auth
              await _auth.signOut();
              // Также выходим из Supabase для совместимости
              await _supabase.auth.signOut();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Приветствие
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Добро пожаловать!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Вы вошли как: ${_supabase.auth.currentUser?.email ?? 'Пользователь'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Кнопка записи
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecordingAndRecognize : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(
                _isRecording ? 'Остановить запись' : 'Начать запись',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Индикатор процесса
            if (_isProcessing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Обработка...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],
            
            // Распознанный текст
            if (_recognizedText.isNotEmpty) ...[
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Результат распознавания:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_recognizedText),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _saveRecord,
                              icon: const Icon(Icons.save),
                              label: const Text('Сохранить запись'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : () {
                                setState(() {
                                  _recognizedText = '';
                                });
                              },
                              child: const Text('Очистить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Сохраненные записи
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сохраненные записи:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _savedRecords.isEmpty
                        ? const Center(
                            child: Text(
                              'Нет сохраненных записей',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _savedRecords.length,
                            itemBuilder: (context, index) {
                              final record = _savedRecords[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(
                                    record['text']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Создано: ${_formatDate(record['created_at'])}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteRecord(record['id'].toString()),
                                  ),
                                  onTap: () {
                                    _showRecordDetails(record);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Форматирование даты
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // Показать детали записи
  void _showRecordDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Запись'),
        content: SingleChildScrollView(
          child: Text(record['text']?.toString() ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}