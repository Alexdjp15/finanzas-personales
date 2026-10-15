import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_providers.dart';
import '../utils/app_theme.dart';
import '../widgets/app_logo_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final isDemoReq = uri.queryParameters['demo'] == 'true' ||
          uri.queryParameters['demo'] == '1' ||
          uri.queryParameters['action'] == 'demo';
      if (isDemoReq && mounted && !_isSignUp) {
        _loginDemoUser();
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginDemoUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _identifierController.text = 'demo_tester';
      _passwordController.text = 'Password123!';
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signIn(identifier: 'demo_tester', password: 'Password123!');
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is StateError) {
            _errorMessage = e.message;
          } else {
            _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSignUpMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;

      // Transfer input smartly between login and registration
      if (_isSignUp) {
        final currentText = _identifierController.text.trim();
        if (currentText.contains('@')) {
          _emailController.text = currentText;
          if (_usernameController.text.isEmpty) {
            _usernameController.text = currentText.split('@').first;
          }
        } else if (currentText.isNotEmpty) {
          _usernameController.text = currentText;
        }
      } else {
        if (_identifierController.text.isEmpty) {
          _identifierController.text = _usernameController.text.isNotEmpty
              ? _usernameController.text
              : _emailController.text;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        final email = _emailController.text.trim();
        final username = _usernameController.text.trim();
        await authRepo.signUp(email: email, password: password, username: username);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta creada con éxito. Ya puedes iniciar sesión.')),
          );
        }
      } else {
        final identifier = _identifierController.text.trim();
        await authRepo.signIn(identifier: identifier, password: password);
      }
    } catch (e) {
      setState(() {
        if (e is StateError) {
          _errorMessage = e.message;
        } else {
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: AppDecorations.card(borderRadius: 24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Prominent Isotype Container (104px height, clean padding, crisp logo)
                      Center(
                        child: Container(
                          height: 104,
                          width: 104,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: const AppLogoWidget(
                              size: 88,
                              useIsotype: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Institutional Brand Typography (separated from the clean isotype graphic)
                      const Text(
                        'APF',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Asistente de Presupuesto & Finanzas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Screen Mode Title
                      Text(
                        _isSignUp ? 'Crear Cuenta' : 'Iniciar Sesión',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? 'Registra tu usuario único para gestionar tus cuentas'
                            : 'Accede a tu panel con tu correo o nombre de usuario',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.liabilityNegativeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.liabilityNegativeBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 18, color: AppColors.liabilityNegative),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.liabilityNegative, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Inputs
                      if (!_isSignUp) ...[
                        // Login Mode: Single field for Email OR Username
                        TextFormField(
                          key: const Key('input_login_identifier'),
                          controller: _identifierController,
                          decoration: const InputDecoration(
                            labelText: 'Correo o Usuario',
                            hintText: 'ej. alex@email.com o alex123',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu correo o nombre de usuario';
                            }
                            if (value.trim().length < 3) {
                              return 'Debe tener al menos 3 caracteres';
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        // Registration Mode: Username Field
                        TextFormField(
                          key: const Key('input_register_username'),
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de usuario único',
                            hintText: 'ej. alex123',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa un nombre de usuario';
                            }
                            final clean = value.trim();
                            if (clean.length < 3 || clean.length > 30) {
                              return 'El usuario debe tener entre 3 y 30 caracteres';
                            }
                            if (clean.contains('@')) {
                              return 'El nombre de usuario no puede contener "@"';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(clean)) {
                              return 'Solo letras, números, puntos y guiones';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Registration Mode: Email Field
                        TextFormField(
                          key: const Key('input_register_email'),
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            hintText: 'ej. alex@email.com',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un correo';
                            }
                            if (!value.contains('@')) {
                              return 'Ingresa un correo electrónico válido';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Password Field (both modes)
                      TextFormField(
                        key: const Key('input_login_password'),
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _isSignUp ? 'Registrarse' : 'Ingresar',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                      if (!_isSignUp) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('btn_login_demo'),
                          onPressed: _isLoading ? null : _loginDemoUser,
                          icon: const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFD97706)),
                          label: const Text(
                            'Entrar a Cuenta Demo',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCD34D), width: 1.5),
                            backgroundColor: const Color(0xFFFEF3C7),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Toggle Button
                      TextButton(
                        onPressed: _isLoading ? null : _toggleSignUpMode,
                        child: Text(
                          _isSignUp
                              ? '¿Ya tienes una cuenta? Inicia sesión'
                              : '¿No tienes cuenta? Regístrate aquí',
                          style: const TextStyle(color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
