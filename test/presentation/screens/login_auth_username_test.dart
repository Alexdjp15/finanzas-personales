import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/repositories/auth_repository.dart';
import 'package:finanzas_personales/presentation/providers/supabase_providers.dart';
import 'package:finanzas_personales/presentation/screens/login_screen.dart';
import 'package:finanzas_personales/presentation/utils/app_theme.dart';
import 'package:finanzas_personales/presentation/widgets/app_logo_widget.dart';

class MockAuthRepository implements AuthRepository {
  String? lastIdentifier;
  String? lastPassword;
  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignUpUsername;
  String? errorToThrow;

  @override
  String? get currentUserId => 'mock-user-123';

  @override
  String? get currentUsername => 'mock_tester';

  @override
  Stream<bool> authStateChanges() => Stream.value(true);

  @override
  Future<String?> getEmailByUsername(String username) async {
    if (username.toLowerCase() == 'alex123') {
      return 'alex@example.com';
    }
    return null;
  }

  @override
  Future<void> signIn({required String identifier, required String password}) async {
    if (errorToThrow != null) {
      throw StateError(errorToThrow!);
    }
    lastIdentifier = identifier;
    lastPassword = password;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    if (errorToThrow != null) {
      throw StateError(errorToThrow!);
    }
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    lastSignUpUsername = username;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  Future<void> initLoginScreen(WidgetTester tester, {Size size = const Size(1280, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LoginScreen Brand and Layout Tests', () {
    testWidgets('renders clean isotype card, typography APF and login form', (tester) async {
      await initLoginScreen(tester);

      // Verify clean isotype widget exists
      expect(find.byType(AppLogoWidget), findsOneWidget);

      // Verify separated institutional typography
      expect(find.text('APF'), findsOneWidget);
      expect(find.text('Asistente de Presupuesto & Finanzas'), findsOneWidget);

      // Verify login mode fields
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('Correo o Usuario'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsOneWidget);
    });

    testWidgets('does not produce RenderFlex overflow on small phone screen', (tester) async {
      await initLoginScreen(tester, size: const Size(360, 640));

      expect(find.text('APF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Login Flow (Email vs Username)', () {
    testWidgets('submitting valid email forwards email to signIn', (tester) async {
      await initLoginScreen(tester);

      // Enter email
      await tester.enterText(find.byKey(const Key('input_login_identifier')), 'alex@example.com');
      // Enter password
      await tester.enterText(find.byKey(const Key('input_login_password')), 'secret123');

      // Tap Ingresar
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastIdentifier, 'alex@example.com');
      expect(mockAuthRepo.lastPassword, 'secret123');
    });

    testWidgets('submitting username forwards username to signIn', (tester) async {
      await initLoginScreen(tester);

      // Enter username without @
      await tester.enterText(find.byKey(const Key('input_login_identifier')), 'alex123');
      await tester.enterText(find.byKey(const Key('input_login_password')), 'secret123');

      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastIdentifier, 'alex123');
      expect(mockAuthRepo.lastPassword, 'secret123');
    });

    testWidgets('displays error banner if signIn fails', (tester) async {
      mockAuthRepo.errorToThrow = 'Credenciales inválidas. Verifica tu contraseña.';

      await initLoginScreen(tester);

      await tester.enterText(find.byKey(const Key('input_login_identifier')), 'alex123');
      await tester.enterText(find.byKey(const Key('input_login_password')), 'wrongpass');

      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Credenciales inválidas. Verifica tu contraseña.'), findsOneWidget);
    });

    testWidgets('validates required fields on login', (tester) async {
      await initLoginScreen(tester);

      // Tap Ingresar without filling inputs
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu correo o nombre de usuario'), findsOneWidget);
      expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);
      expect(mockAuthRepo.lastIdentifier, isNull);
    });
  });

  group('Registration Flow & Mode Switching', () {
    testWidgets('toggling mode transitions to registration with unique username field', (tester) async {
      await initLoginScreen(tester);

      // Switch to registration
      await tester.tap(find.text('¿No tienes cuenta? Regístrate aquí'));
      await tester.pumpAndSettle();

      expect(find.text('Crear Cuenta'), findsOneWidget);
      expect(find.text('Nombre de usuario único'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Registrarse'), findsOneWidget);
      expect(find.text('¿Ya tienes una cuenta? Inicia sesión'), findsOneWidget);
    });

    testWidgets('smart input transfer moves email from login to registration', (tester) async {
      await initLoginScreen(tester);

      // Type email in login identifier field
      await tester.enterText(find.byKey(const Key('input_login_identifier')), 'carolina@finance.com');

      // Click to switch to registration
      await tester.tap(find.text('¿No tienes cuenta? Regístrate aquí'));
      await tester.pumpAndSettle();

      // The email field should be populated, and username pre-filled with the prefix
      final emailField = tester.widget<TextFormField>(find.byKey(const Key('input_register_email')));
      final usernameField = tester.widget<TextFormField>(find.byKey(const Key('input_register_username')));

      expect(emailField.controller?.text, 'carolina@finance.com');
      expect(usernameField.controller?.text, 'carolina');
    });

    testWidgets('submits registration with username, email and password', (tester) async {
      await initLoginScreen(tester);

      await tester.tap(find.text('¿No tienes cuenta? Regístrate aquí'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('input_register_username')), 'david_fin');
      await tester.enterText(find.byKey(const Key('input_register_email')), 'david@gmail.com');
      await tester.enterText(find.byKey(const Key('input_login_password')), 'password123');

      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastSignUpUsername, 'david_fin');
      expect(mockAuthRepo.lastSignUpEmail, 'david@gmail.com');
      expect(mockAuthRepo.lastSignUpPassword, 'password123');
      expect(find.text('Cuenta creada con éxito. Ya puedes iniciar sesión.'), findsOneWidget);
    });

    testWidgets('validates username formatting rules (no @, alphanumeric characters)', (tester) async {
      await initLoginScreen(tester);

      await tester.tap(find.text('¿No tienes cuenta? Regístrate aquí'));
      await tester.pumpAndSettle();

      // Enter username with '@'
      await tester.enterText(find.byKey(const Key('input_register_username')), 'user@bad');
      await tester.enterText(find.byKey(const Key('input_register_email')), 'user@valid.com');
      await tester.enterText(find.byKey(const Key('input_login_password')), 'secret123');

      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre de usuario no puede contener "@"'), findsOneWidget);
      expect(mockAuthRepo.lastSignUpUsername, isNull);
    });

    testWidgets('renders Demo Quick Access button and logs in demo_tester on tap', (tester) async {
      await initLoginScreen(tester);

      expect(find.byKey(const Key('btn_login_demo')), findsOneWidget);
      expect(find.text('Entrar a Cuenta Demo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_login_demo')));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastIdentifier, 'demo_tester');
      expect(mockAuthRepo.lastPassword, 'Password123!');
    });
  });
}
