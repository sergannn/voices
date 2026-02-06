import 'package:flutter/material.dart';

/// Раздел «Метроном».
/// Требования: BPM 40–240, размеры такта 2/4, 3/4, 4/4, 6/8, акцент на первой доле, вибрация/вспышка, режим «разогрев», работа параллельно с другими разделами.
class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Метроном',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        const Text(
          'BPM 40–240, размеры такта 2/4, 3/4, 4/4, 6/8. Акцент на первой доле, опционально вибрация и вспышка. Режим «разогрев» с плавным увеличением темпа.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.timer, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('BPM: 120', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Размер: 4/4'),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Запустить метроном'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Метроном будет реализован')),
    );
  }
}
