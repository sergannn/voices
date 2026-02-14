import 'package:flutter/material.dart';
import '../widgets/home_record_content.dart';

/// Раздел «Рудименты» — подразделы как в Уроки: список рудиментов, по нажатию — контент как на главной (пока).
class RudimentsScreen extends StatelessWidget {
  const RudimentsScreen({super.key});

  static const List<Map<String, String>> _rudiments = [
    {'title': 'Single Stroke Roll', 'subtitle': 'Одиночные удары поочерёдно'},
    {'title': 'Single Stroke Four', 'subtitle': 'Четыре одиночных удара'},
    {'title': 'Single Stroke Seven', 'subtitle': 'Семь одиночных ударов'},
    {'title': 'Multiple Bounce Roll', 'subtitle': 'Многократный отскок'},
    {'title': 'Double Stroke Roll', 'subtitle': 'Двойные удары'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Рудименты',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Базовые рудименты для развития техники: список упражнений. По нажатию открывается экран с контентом как на главной.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        ..._rudiments.map((r) => _RudimentTile(
              title: r['title']!,
              subtitle: r['subtitle']!,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => RudimentDetailScreen(
                    title: r['title']!,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _RudimentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RudimentTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.music_note, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}

/// Экран рудимента: тот же рабочий контент, что и на главной (запись, волновая форма, сохранённые записи).
class RudimentDetailScreen extends StatelessWidget {
  final String title;

  const RudimentDetailScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Запись, волновая форма и сохранённые записи работают так же, как на главной.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const HomeRecordContent(),
          ],
        ),
      ),
    );
  }
}
