import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/providers/finance_state_providers.dart';
import 'presentation/providers/supabase_providers.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read environment variables passed via --dart-define or fallback to project .env
  const envUrl = String.fromEnvironment('SUPABASE_URL');
  const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final supabaseUrl = envUrl.isNotEmpty
      ? envUrl
      : 'https://ciesbycnqesrubtcrjbm.supabase.co';
  final supabaseAnonKey = envAnonKey.isNotEmpty
      ? envAnonKey
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpZXNieWNucWVzcnVidGNyamJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEzODA5NTcsImV4cCI6MjEwNjk1Njk1N30.Lz-LZuI6Pf1x9ZKySR5SFONvOy-v1FZWuXMydf3zDfs';

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: FinanzasApp()));
}

class FinanzasApp extends ConsumerWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Finanzas Personales',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (isAuthenticated) {
        if (!isAuthenticated) {
          return const LoginScreen();
        }

        final onboardingAsync = ref.watch(onboardingStatusProvider);
        return onboardingAsync.when(
          data: (completed) => completed ? const DashboardScreen() : const OnboardingScreen(),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => const DashboardScreen(),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => const LoginScreen(),
    );
  }
}
