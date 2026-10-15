// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'package:supabase/supabase.dart';

const supabaseUrl = 'https://ciesbycnqesrubtcrjbm.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpZXNieWNucWVzcnVidGNyamJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEzODA5NTcsImV4cCI6MjEwNjk1Njk1N30.Lz-LZuI6Pf1x9ZKySR5SFONvOy-v1FZWuXMydf3zDfs';

const testEmail = 'demo_tester@finanzas.app';
const testUsername = 'demo_tester';
const testPassword = 'Password123!';

Future<void> main() async {
  final client = SupabaseClient(
    supabaseUrl,
    supabaseAnonKey,
    authOptions: const AuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // 1. Intentar registrar el usuario o iniciar sesión
  print('Iniciando sesión o registrando usuario de prueba ($testUsername / $testEmail)...');
  try {
    final signUpRes = await client.auth.signUp(
      email: testEmail,
      password: testPassword,
      data: {'username': testUsername},
    );
    print('SignUp ejecutado. User ID: ${signUpRes.user?.id}');
  } catch (e, st) {
    print('Nota al registrar (puede que ya exista): $e\n$st');
  }

  // Iniciar sesión para obtener la sesión autenticada y el JWT con RLS
  final signInRes = await client.auth.signInWithPassword(
    email: testEmail,
    password: testPassword,
  );
  final user = signInRes.user;
  if (user == null) {
    throw Exception('No se pudo autenticar el usuario de prueba.');
  }
  print('✓ Usuario autenticado con éxito! UUID: ${user.id}');

  // Asegurar registro en profiles
  try {
    await client.from('profiles').upsert({
      'id': user.id,
      'username': testUsername,
      'email': testEmail,
      'created_at': DateTime.now().toIso8601String(),
    });
    print('✓ Perfil asegurado en tabla profiles.');
  } catch (e) {
    print('Aviso perfil: $e');
  }

  // Asegurar registro en user_settings con onboarding_completed = true
  try {
    await client.from('user_settings').upsert({
      'user_id': user.id,
      'onboarding_completed': true,
      'reminder_hour': 8,
      'reminder_minute': 0,
    });
    print('✓ Configuración asegurada en tabla user_settings (onboarding_completed: true).');
  } catch (e) {
    print('Aviso user_settings: $e');
  }

  // 2. Verificar si ya tiene cuentas creadas
  final existingAccounts = await client.from('accounts').select('id, name');
  if ((existingAccounts as List).isNotEmpty) {
    print('El usuario ya cuenta con ${(existingAccounts).length} cuentas creadas.');
    print('Limpiando datos previos del usuario de prueba para refrescar con nuevos datos...');
    // Limpieza segura únicamente para este usuario autenticado (RLS filtra automáticamente por auth.uid())
    try {
      await client.from('aliases').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await client.from('transactions').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await client.from('recurring_payments').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await client.from('pockets').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await client.from('credit_cards').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await client.from('accounts').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✓ Datos anteriores limpiados exitosamente.');
    } catch (e) {
      print('Aviso al limpiar: $e');
    }
  }

  print('\n--- Poblando Cuentas Bancarias y Bolsillos ---');
  // Cuenta 1: Bancolombia
  final accBancolombia = await client
      .from('accounts')
      .insert({'name': 'Bancolombia', 'account_number': '1089-234567'})
      .select('id, name')
      .single();
  final bancolombiaId = accBancolombia['id'] as String;

  // Bolsillos Bancolombia
  final pckBancoDisp = await client
      .from('pockets')
      .insert({'account_id': bancolombiaId, 'name': 'Disponible en Cuenta', 'balance': 450000})
      .select('id')
      .single();
  final pckPersonal = await client
      .from('pockets')
      .insert({'account_id': bancolombiaId, 'name': 'Personal', 'balance': 380000})
      .select('id')
      .single();
  final pckArriendo = await client
      .from('pockets')
      .insert({'account_id': bancolombiaId, 'name': 'Arriendo', 'balance': 1200000})
      .select('id')
      .single();
  final pckAhorro = await client
      .from('pockets')
      .insert({'account_id': bancolombiaId, 'name': 'Ahorro Vacaciones', 'balance': 850000})
      .select('id')
      .single();

  // Cuenta 2: Nequi
  final accNequi = await client
      .from('accounts')
      .insert({'name': 'Nequi', 'account_number': '300 123 4567'})
      .select('id, name')
      .single();
  final nequiId = accNequi['id'] as String;

  // Bolsillos Nequi
  final pckNequiDisp = await client
      .from('pockets')
      .insert({'account_id': nequiId, 'name': 'Disponible', 'balance': 135000})
      .select('id')
      .single();
  final pckNequiComidas = await client
      .from('pockets')
      .insert({'account_id': nequiId, 'name': 'Comidas y Salidas', 'balance': 90000})
      .select('id')
      .single();

  // Cuenta 3: Daviplata
  final accDaviplata = await client
      .from('accounts')
      .insert({'name': 'Daviplata', 'account_number': '310 987 6543'})
      .select('id, name')
      .single();
  final daviplataId = accDaviplata['id'] as String;

  // Bolsillo Daviplata
  final pckDaviServicios = await client
      .from('pockets')
      .insert({'account_id': daviplataId, 'name': 'Servicios Públicos', 'balance': 160000})
      .select('id')
      .single();

  print('✓ 3 Cuentas bancarias y 7 bolsillos creados.');

  print('\n--- Poblando Tarjetas de Crédito ---');
  // Tarjeta 1: RappiCard
  final cardRappi = await client
      .from('credit_cards')
      .insert({
        'entity': 'RappiPay',
        'name': 'RappiCard',
        'franchise': 'Visa',
        'last_four_digits': '4589',
        'credit_limit': 3000000,
        'available_credit': 2450000,
        'currency': 'COP',
        'cut_off_day': 15,
        'payment_due_day': 5,
      })
      .select('id')
      .single();
  final rappiCardId = cardRappi['id'] as String;

  // Tarjeta 2: Tarjeta Nu
  final cardNu = await client
      .from('credit_cards')
      .insert({
        'entity': 'Nu Colombia',
        'name': 'Tarjeta Nu',
        'franchise': 'Mastercard',
        'last_four_digits': '8912',
        'credit_limit': 5000000,
        'available_credit': 4100000,
        'currency': 'COP',
        'cut_off_day': 20,
        'payment_due_day': 10,
      })
      .select('id')
      .single();
  final nuCardId = cardNu['id'] as String;

  print('✓ 2 Tarjetas de crédito creadas (RappiCard y Nu).');

  print('\n--- Registrando Alias para el Motor NLP ---');
  await client.from('aliases').insert([
    {'alias': 'bancolombia', 'account_id': bancolombiaId},
    {'alias': 'cuenta bancolombia', 'account_id': bancolombiaId},
    {'alias': 'nequi', 'account_id': nequiId},
    {'alias': 'cuenta nequi', 'account_id': nequiId},
    {'alias': 'daviplata', 'account_id': daviplataId},
    {'alias': 'rappi', 'card_id': rappiCardId},
    {'alias': 'rappicard', 'card_id': rappiCardId},
    {'alias': 'tc rappi', 'card_id': rappiCardId},
    {'alias': 'nu', 'card_id': nuCardId},
    {'alias': 'nubank', 'card_id': nuCardId},
    {'alias': 'tc nu', 'card_id': nuCardId},
    {'alias': 'personal', 'pocket_id': pckPersonal['id']},
    {'alias': 'arriendo', 'pocket_id': pckArriendo['id']},
    {'alias': 'vacaciones', 'pocket_id': pckAhorro['id']},
    {'alias': 'comidas', 'pocket_id': pckNequiComidas['id']},
    {'alias': 'servicios', 'pocket_id': pckDaviServicios['id']},
  ]);
  print('✓ Alias registrados.');

  print('\n--- Registrando Movimientos e Historial ---');
  final today = DateTime.now();
  String formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 1. Ingreso Nómina Quincena
  await client.from('transactions').insert({
    'type': 'income',
    'pocket_id': pckBancoDisp['id'],
    'amount': 2500000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 3))),
    'description': 'Pago Quincena Nómina',
  });

  // 2. Gasto Mercado Éxito
  await client.from('transactions').insert({
    'type': 'expense',
    'pocket_id': pckPersonal['id'],
    'amount': 185000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 2))),
    'description': 'Mercado Éxito',
  });

  // 3. Gasto Almuerzo en Nequi
  await client.from('transactions').insert({
    'type': 'expense',
    'pocket_id': pckNequiComidas['id'],
    'amount': 28000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 1))),
    'description': 'Almuerzo Restaurante',
  });

  // 4. Compra con Tarjeta RappiCard (Gasolina)
  await client.from('transactions').insert({
    'type': 'card_charge',
    'card_id': rappiCardId,
    'pocket_id': pckPersonal['id'],
    'amount': 50000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 2))),
    'description': 'Gasolina Estación Terpel',
  });

  // 5. Compra con Tarjeta Nu (Farmacia)
  await client.from('transactions').insert({
    'type': 'card_charge',
    'card_id': nuCardId,
    'pocket_id': pckPersonal['id'],
    'amount': 35000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 1))),
    'description': 'Farmacia Droguería La Rebaja',
  });

  // 6. Abono a Tarjeta de Crédito Nu desde Disponible Bancolombia
  await client.from('transactions').insert({
    'type': 'card_payment',
    'card_id': nuCardId,
    'pocket_id': pckBancoDisp['id'],
    'amount': 400000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 1))),
    'description': 'Abono Tarjeta de Crédito Nu',
  });

  // 7. Transferencia entre bolsillos (Personal a Ahorro Vacaciones)
  await client.from('transactions').insert({
    'type': 'pocket_transfer',
    'pocket_id': pckPersonal['id'],
    'target_pocket_id': pckAhorro['id'],
    'amount': 150000,
    'occurred_on': formatDate(today.subtract(const Duration(days: 4))),
    'description': 'Ahorro para vacaciones de fin de año',
  });
  print('✓ 7 Transacciones reales registradas en historial.');

  print('\n--- Registrando Suscripciones y Pagos Recurrentes ---');
  await client.from('recurring_payments').insert([
    {
      'name': 'Netflix 4K',
      'amount': 45000,
      'day_of_month': 15,
      'start_date': formatDate(today.subtract(const Duration(days: 30))),
      'method_type': 'credit_card',
      'pocket_id': pckPersonal['id'],
      'card_id': rappiCardId,
      'auto_deduct': true,
    },
    {
      'name': 'Spotify Familiar',
      'amount': 26900,
      'day_of_month': 5,
      'start_date': formatDate(today.subtract(const Duration(days: 60))),
      'method_type': 'credit_card',
      'pocket_id': pckPersonal['id'],
      'card_id': nuCardId,
      'auto_deduct': true,
    },
    {
      'name': 'Factura Internet Claro',
      'amount': 95000,
      'day_of_month': 10,
      'start_date': formatDate(today.subtract(const Duration(days: 45))),
      'method_type': 'account_pocket',
      'pocket_id': pckBancoDisp['id'],
      'card_id': null,
      'auto_deduct': false,
    },
    {
      'name': 'Recibo del Agua (Monto Variable)',
      'amount': 0,
      'day_of_month': 18,
      'start_date': formatDate(today.subtract(const Duration(days: 15))),
      'method_type': 'account_pocket',
      'pocket_id': pckDaviServicios['id'],
      'card_id': null,
      'auto_deduct': false,
    },
    {
      'name': 'Gimnasio SmartFit',
      'amount': 89000,
      'day_of_month': 1,
      'start_date': formatDate(today.subtract(const Duration(days: 20))),
      'method_type': 'account_pocket',
      'pocket_id': pckNequiDisp['id'],
      'card_id': null,
      'auto_deduct': true,
    },
  ]);
  print('✓ 5 Suscripciones y recordatorios recurrentes creados.');

  print('\n=============================================================');
  print('🎉 USUARIO DE PRUEBA CREADO Y POBLADO CON ÉXITO');
  print('=============================================================');
  print('Usuario (Username) : $testUsername');
  print('Correo Electrónico : $testEmail');
  print('Contraseña         : $testPassword');
  print('-------------------------------------------------------------');
  print('Cuentas Bancarias  : Bancolombia, Nequi, Daviplata');
  print('Tarjetas de Crédito: RappiCard, Tarjeta Nu');
  print('Total Bolsillos    : 7 bolsillos con saldos reales');
  print('Transacciones      : 7 movimientos registrados (ingresos, gastos, abonos, transferencias)');
  print('Suscripciones      : Netflix, Spotify, Claro, Recibo del Agua (\$0 COP), SmartFit');
  print('=============================================================\n');
  exit(0);
}
