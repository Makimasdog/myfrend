import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/theme.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/ai_friend_provider.dart';
import 'src/providers/chat_provider.dart';
import 'src/services/api_service.dart';
import 'src/pages/login_page.dart';
import 'src/pages/home_page.dart';

void main() {
  final apiService = ApiService();
  runApp(MyFrendsApp(apiService: apiService));
}

class MyFrendsApp extends StatelessWidget {
  final ApiService apiService;
  const MyFrendsApp({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => AiFriendProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ChatProvider(apiService)),
      ],
      child: MaterialApp(
        title: 'myfrends',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// 认证网关
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with SingleTickerProviderStateMixin {
  bool _initialized = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _init();
  }

  Future<void> _init() async {
    await context.read<AuthProvider>().init();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_rounded,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ]),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    return FadeTransition(
      opacity: _fadeAnim,
      child: auth.isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}
