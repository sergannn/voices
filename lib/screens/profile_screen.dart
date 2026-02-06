import 'package:flutter/material.dart';

/// Раздел «Профиль» и настройки.
/// Требования: язык (RU/EN), тема (светлая/тёмная), громкость метронома и семплов, чувствительность микрофона, калибровка задержки.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.userEmail,
    required this.onLogout,
  });

  final String? userEmail;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Профиль',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (userEmail != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Почта'),
              subtitle: Text(userEmail!),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Настройки',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Язык'),
                subtitle: const Text('Русский'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Тема'),
                subtitle: const Text('Светлая'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('Громкость метронома и семплов'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Чувствительность микрофона'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Калибровка задержки звука'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Выйти'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки будут доступны')),
    );
  }
}
