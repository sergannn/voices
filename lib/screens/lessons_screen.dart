import 'package:flutter/material.dart';

/// Раздел «Уроки» — структурированные уроки по основам игры на ударных.
/// Требования: теория, навигация внутри урока, практика, табулатура R/L, 75% для прохождения, блокировка следующего.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Уроки',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Структурированные уроки по основам игры на ударных: теория, рудименты, практические упражнения с табулатурой (R/L).',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _LessonTile(
          title: 'Урок 1',
          subtitle: 'Основы постановки рук',
          locked: false,
          onTap: () => _showComingSoon(context),
        ),
        _LessonTile(
          title: 'Урок 2',
          subtitle: 'Одиночные удары',
          locked: true,
          onTap: () {},
        ),
        _LessonTile(
          title: 'Урок 3',
          subtitle: 'Двойные удары',
          locked: true,
          onTap: () {},
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Содержимое урока будет добавлено')),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback onTap;

  const _LessonTile({
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(locked ? Icons.lock : Icons.school, color: locked ? Colors.grey : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: locked ? const Icon(Icons.lock_outline) : const Icon(Icons.arrow_forward),
        onTap: locked ? null : onTap,
      ),
    );
  }
}
