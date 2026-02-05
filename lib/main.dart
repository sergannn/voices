import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show User;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
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
  final _volumeController = TextEditingController();
  final _sizeController = TextEditingController();
  String _recognizedText = '';
  bool _isRecording = false;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _savedRecords = [];
  String? _currentRecordingPath;
  String? _waveformImageBase64;

  @override
  void initState() {
    super.initState();
    _loadSavedRecords();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _volumeController.dispose();
    _sizeController.dispose();
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
        String? filePath;
        
        if (kIsWeb) {
          // На веб-платформе записываем без указания пути (получим blob URL)
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.opus),
            path: '',
          );
        } else {
          // На нативных платформах используем файловую систему
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          filePath = '${directory.path}/recording_$timestamp.m4a';
          
          await _audioRecorder.start(
            const RecordConfig(),
            path: filePath,
          );
        }
        
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
      // Останавливаем запись и получаем путь к файлу (или blob URL на web)
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      if (path != null && path.isNotEmpty) {
        String fileInfo;
        
        if (kIsWeb) {
          // На web получаем blob URL
          fileInfo = 'Blob URL получен';
        } else {
          // На нативных платформах проверяем файл
          final file = File(path);
          if (await file.exists()) {
            final fileSize = await file.length();
            fileInfo = 'Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB';
          } else {
            throw Exception('Файл записи не найден');
          }
        }
        
        // Имитация распознавания речи (здесь можно добавить реальное распознавание)
        await Future.delayed(const Duration(seconds: 2));
        
        // Пример распознанного текста
        final sampleTexts = [
          'Это пример распознанного текста из аудиозаписи. $fileInfo',
          'Сегодня прекрасная погода для прогулки в парке. Солнце светит ярко, птицы поют свои песни. $fileInfo',
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

  // Получение байтов аудио записи
  Future<Uint8List?> _getAudioBytes() async {
    if (_currentRecordingPath == null || _currentRecordingPath!.isEmpty) {
      return null;
    }

    if (kIsWeb) {
      // На web получаем blob по URL
      try {
        final response = await http.get(Uri.parse(_currentRecordingPath!));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Ошибка получения blob: $e');
      }
      return null;
    } else {
      // На нативных платформах читаем файл
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    }
  }

  // Отправка записи на сервер
  Future<void> _saveRecord() async {
    if (_currentRecordingPath == null || _currentRecordingPath!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет записи для отправки')),
        );
      }
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Получаем байты аудио
      final audioBytes = await _getAudioBytes();

      if (audioBytes == null || audioBytes.isEmpty) {
        throw Exception('Не удалось получить аудио данные');
      }

      // Отправляем на сервер
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = kIsWeb ? 'webm' : 'm4a';
      final filename = 'recording_$timestamp.$extension';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://music.panfilius.ru/api/newRecord'),
      );

  //    request.fields['volume'] = _volumeController.text;
  //    request.fields['size'] = _sizeController.text;

      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: filename,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? waveformBase64;
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>?;
          final data = json?['data'] as Map<String, dynamic>?;
          if (data != null && data['waveform_image'] != null) {
            waveformBase64 = data['waveform_image'] as String;
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запись отправлена на сервер!'),
              duration: Duration(seconds: 3),
            ),
          );

          setState(() {
            _recognizedText = '';
            _currentRecordingPath = null;
            _waveformImageBase64 = waveformBase64;
          });
        }
      } else {
        throw Exception('Сервер вернул ошибку: ${response.statusCode}');
      }

      /* // Supabase Storage (временно отключено)
      String? storagePath;
      if (audioBytes != null && audioBytes.isNotEmpty) {
        final userId = _supabase.auth.currentUser!.id;
        final extension = kIsWeb ? 'webm' : 'm4a';
        storagePath = '$userId/recording_$timestamp.$extension';

        await _supabase.storage
            .from('audio_recordings')
            .uploadBinary(
              storagePath,
              audioBytes,
              fileOptions: FileOptions(
                contentType: kIsWeb ? 'audio/webm' : 'audio/m4a',
              ),
            );
      }

      // Сохраняем информацию о записи в базу данных
      final record = {
        'user_id': _supabase.auth.currentUser!.id,
        'text': _recognizedText,
        'file_path': storagePath ?? 'no_audio',
        'created_at': DateTime.now().toIso8601String(),
      };

      final dbResponse = await _supabase
          .from('audio_records')
          .insert(record)
          .select();

      if (dbResponse.isNotEmpty) {
        await _loadSavedRecords();
      }
      */
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
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
            // громкость - потом
            TextFormField(
              controller: _volumeController,
              decoration: const InputDecoration(
                icon: Icon(Icons.volume_up),
                hintText: 'Пропишите громкость',
                labelText: 'Громкость',
              ),
            ),
            TextFormField(
              controller: _sizeController,
              decoration: const InputDecoration(
                icon: Icon(Icons.straighten),
                hintText: 'Пропишите размер',
                labelText: 'Размер',
              ),
            ),
            const SizedBox(height: 16),

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

            // Waveform от сервера
            if (_waveformImageBase64 != null && _waveformImageBase64!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Волновая форма',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Image.memory(
                        base64Decode(_waveformImageBase64!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _waveformImageBase64 = null),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Скрыть'),
                      ),
                    ],
                  ),
                ),
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
                    /*      TextFormField(
  decoration: const InputDecoration(
    icon: Icon(Icons.person),
    hintText: 'What do people call you?',
    labelText: 'Name *',
  )),
                          TextFormField(),*/

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