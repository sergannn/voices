import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Общий виджет записи, волновой формы и списка сохранённых записей.
/// Используется на главной и в экране рудимента. Работает как раньше на главной.
class HomeRecordContent extends StatefulWidget {
  /// Опционально: при изменении числа записей (для блока статистики на главной).
  final void Function(int count)? onRecordCountChanged;

  const HomeRecordContent({super.key, this.onRecordCountChanged});

  @override
  State<HomeRecordContent> createState() => _HomeRecordContentState();
}

class _HomeRecordContentState extends State<HomeRecordContent> {
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

  void _notifyRecordCount() {
    widget.onRecordCountChanged?.call(_savedRecords.length);
  }

  Future<void> _loadSavedRecords() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final response = await _supabase
          .from('audio_records')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _savedRecords = List<Map<String, dynamic>>.from(response);
        });
        _notifyRecordCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки записей: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? filePath;
        if (kIsWeb) {
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.opus),
            path: '',
          );
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          filePath = '${directory.path}/recording_$timestamp.m4a';
          await _audioRecorder.start(
            const RecordConfig(),
            path: filePath,
          );
        }
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recognizedText = '';
            _currentRecordingPath = filePath;
          });
        }
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
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecordingAndRecognize() async {
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      if (path != null && path.isNotEmpty) {
        String fileInfo;
        if (kIsWeb) {
          fileInfo = 'Blob URL получен';
        } else {
          final file = File(path);
          if (await file.exists()) {
            final fileSize = await file.length();
            fileInfo = 'Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB';
          } else {
            throw Exception('Файл записи не найден');
          }
        }
        await Future.delayed(const Duration(seconds: 2));
        final sampleTexts = [
          'Это пример распознанного текста из аудиозаписи. $fileInfo',
          'Сегодня прекрасная погода для прогулки в парке. $fileInfo',
          'Технологии искусственного интеллекта стремительно развиваются. Запись сохранена успешно.',
          'Для успешного выполнения задачи необходимо тщательное планирование. Аудио файл готов.',
        ];
        final randomText = sampleTexts[DateTime.now().millisecondsSinceEpoch % sampleTexts.length];
        if (mounted) {
          setState(() {
            _recognizedText = randomText;
            _isProcessing = false;
            _currentRecordingPath = path;
          });
        }
      } else {
        throw Exception('Не удалось получить путь к файлу записи');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recognizedText = 'Ошибка при остановке записи: $e';
          _isProcessing = false;
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _getAudioBytes() async {
    if (_currentRecordingPath == null || _currentRecordingPath!.isEmpty) return null;
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse(_currentRecordingPath!));
        if (response.statusCode == 200) return response.bodyBytes;
      } catch (e) {
        debugPrint('Ошибка получения blob: $e');
      }
      return null;
    } else {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) return await file.readAsBytes();
      return null;
    }
  }

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
      setState(() => _isProcessing = true);
      final audioBytes = await _getAudioBytes();
      if (audioBytes == null || audioBytes.isEmpty) {
        throw Exception('Не удалось получить аудио данные');
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = kIsWeb ? 'webm' : 'm4a';
      final filename = 'recording_$timestamp.$extension';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://music.panfilius.ru/api/newRecord'),
      );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase
          .from('audio_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', user.id);
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (_waveformImageBase64 != null && _waveformImageBase64!.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Волновая форма',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          onPressed: _isProcessing
                              ? null
                              : () => setState(() => _recognizedText = ''),
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
        const Text(
          'Сохраненные записи:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _savedRecords.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Нет сохраненных записей',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                        'Создано: ${_formatDate(record['created_at']?.toString() ?? '')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecord(record['id'].toString()),
                      ),
                      onTap: () => _showRecordDetails(record),
                    ),
                  );
                },
              ),
        const SizedBox(height: 24),
      ],
    );
  }
}
