import 'package:flutter/material.dart';

/// Раздел «Редактор табов» (тренировки).
/// Требования: создание/редактирование табулатур, сохранение, проигрывание эталона, подсветка удара, режим тренировки с метрономом.
class TabEditorScreen extends StatelessWidget {
  const TabEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Редактор табов',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Создавайте свои упражнения: ввод табулатур (текст или кнопки), сохранение, проигрывание эталона с подсветкой, режим тренировки с метрономом.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Новый таб'),
            subtitle: const Text('Создать упражнение'),
            onTap: () => _showComingSoon(context),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Мои табы'),
            subtitle: const Text('Сохранённые упражнения'),
            onTap: () => _showComingSoon(context),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Редактор табов будет реализован')),
    );
  }
}
