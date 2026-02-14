import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show User;
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'register.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/lessons_screen.dart';
import 'screens/rudiments_screen.dart';
import 'screens/tab_editor_screen.dart';
import 'screens/metronome_screen.dart';
import 'screens/profile_screen.dart';
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
      title: 'Drum Coach',
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

  int _selectedIndex = 0;
  static const int _lessonsTotal = 10;
  int _lessonsPassed = 0;
  double _bestResultPercent = 0;
  int _recordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRecordCount();
  }

  Future<void> _loadRecordCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final response = await _supabase
          .from('audio_records')
          .select('id')
          .eq('user_id', user.id);
      if (mounted) setState(() => _recordCount = response.length);
    } catch (_) {}
  }

  String get _appBarTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Главная';
      case 1:
        return 'Уроки';
      case 2:
        return 'Рудименты';
      case 3:
        return 'Редактор табов';
      case 4:
        return 'Метроном';
      case 5:
        return 'Профиль';
      default:
        return 'Drum Coach';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              await _supabase.auth.signOut();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const LessonsScreen(),
          const RudimentsScreen(),
          const TabEditorScreen(),
          const MetronomeScreen(),
          ProfileScreen(
            userEmail: _supabase.auth.currentUser?.email,
            onLogout: () async {
              await _auth.signOut();
              await _supabase.auth.signOut();
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Уроки'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Рудименты'),
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Табы'),
          NavigationDestination(icon: Icon(Icons.timer), label: 'Метроном'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Общая статистика
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Общая статистика',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.school,
                          value: '$_lessonsPassed',
                          label: 'Уроков пройдено',
                          total: '$_lessonsTotal',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.music_note,
                          value: '0',
                          label: 'Рудиментов',
                          total: '5',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.mic,
                          value: '$_recordCount',
                          label: 'Записей',
                          total: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.emoji_events,
                          value: _bestResultPercent > 0 ? '${_bestResultPercent.toStringAsFixed(0)}%' : '—',
                          label: 'Лучший результат',
                          total: null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          // Информация о прогрессе (требования 1.4.1 — главная страница)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пройдено $_lessonsPassed из $_lessonsTotal уроков',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bestResultPercent > 0
                        ? 'Лучший результат: ${_bestResultPercent.toStringAsFixed(0)}%'
                        : 'Лучший результат: —',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ],
        ),
    );
  }

}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? total;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            total != null ? '$value / $total' : value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}