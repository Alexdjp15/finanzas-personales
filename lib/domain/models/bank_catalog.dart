import 'package:flutter/material.dart';

class BankItem {
  const BankItem({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.primaryColor,
    required this.aliases,
  });

  final String id;
  final String name;
  final String assetPath;
  final Color primaryColor;
  final List<String> aliases;

  bool get isCustom => id == 'otro';
}

class BankCatalog {
  const BankCatalog._();

  static List<BankItem> get banks => items;

  static const items = <BankItem>[
    BankItem(
      id: 'bancolombia',
      name: 'Bancolombia',
      assetPath: 'assets/icons/banks/bancolombia.png',
      primaryColor: Color(0xFFFDDA24),
      aliases: ['bancolombia', 'bancolombia sa', 'banco de colombia'],
    ),
    BankItem(
      id: 'nequi',
      name: 'Nequi',
      assetPath: 'assets/icons/banks/nequi.png',
      primaryColor: Color(0xFFE0004D),
      aliases: ['nequi'],
    ),
    BankItem(
      id: 'davivienda',
      name: 'Davivienda',
      assetPath: 'assets/icons/banks/davivienda.png',
      primaryColor: Color(0xFFED1C24),
      aliases: ['davivienda', 'banco davivienda'],
    ),
    BankItem(
      id: 'daviplata',
      name: 'Daviplata',
      assetPath: 'assets/icons/banks/daviplata.png',
      primaryColor: Color(0xFFE31B23),
      aliases: ['daviplata'],
    ),
    BankItem(
      id: 'nu',
      name: 'Nu',
      assetPath: 'assets/icons/banks/nu.png',
      primaryColor: Color(0xFF820AD1),
      aliases: ['nu', 'nubank', 'cuenta nu'],
    ),
    BankItem(
      id: 'lulo',
      name: 'Lulo Bank',
      assetPath: 'assets/icons/banks/lulo.png',
      primaryColor: Color(0xFFB4FF00),
      aliases: ['lulo', 'lulo bank'],
    ),
    BankItem(
      id: 'bogota',
      name: 'Banco de Bogotá',
      assetPath: 'assets/icons/banks/bogota.png',
      primaryColor: Color(0xFF002D72),
      aliases: ['bogota', 'banco de bogota', 'banco bogota', 'bogotá'],
    ),
    BankItem(
      id: 'bbva',
      name: 'BBVA',
      assetPath: 'assets/icons/banks/bbva.png',
      primaryColor: Color(0xFF004481),
      aliases: ['bbva', 'banco bbva'],
    ),
    BankItem(
      id: 'colpatria',
      name: 'Scotiabank Colpatria',
      assetPath: 'assets/icons/banks/colpatria.png',
      primaryColor: Color(0xFFED1C24),
      aliases: ['colpatria', 'scotiabank', 'scotiabank colpatria'],
    ),
    BankItem(
      id: 'falabella',
      name: 'Banco Falabella',
      assetPath: 'assets/icons/banks/falabella.png',
      primaryColor: Color(0xFF8AB833),
      aliases: ['falabella', 'banco falabella', 'cmr'],
    ),
    BankItem(
      id: 'rappipay',
      name: 'RappiPay',
      assetPath: 'assets/icons/banks/rappipay.png',
      primaryColor: Color(0xFFFF441F),
      aliases: ['rappipay', 'rappi pay', 'rappi'],
    ),
    BankItem(
      id: 'dale',
      name: 'Dale!',
      assetPath: 'assets/icons/banks/dale.png',
      primaryColor: Color(0xFF00D1C1),
      aliases: ['dale', 'dale!'],
    ),
    BankItem(
      id: 'revolut',
      name: 'Revolut',
      assetPath: 'assets/icons/banks/revolut.png',
      primaryColor: Color(0xFF0075EB),
      aliases: ['revolut'],
    ),
    BankItem(
      id: 'otro',
      name: 'Otro / Personalizado',
      assetPath: 'assets/icons/banks/default_bank.png',
      primaryColor: Color(0xFF6B7280),
      aliases: ['otro', 'personalizado', 'banco'],
    ),
  ];

  static BankItem get other => items.firstWhere((b) => b.id == 'otro');

  static BankItem? findById(String id) {
    final norm = id.trim().toLowerCase();
    for (final item in items) {
      if (item.id.toLowerCase() == norm) return item;
    }
    return null;
  }

  static BankItem? findByName(String name) {
    final norm = _normalize(name);
    for (final item in items) {
      if (_normalize(item.name) == norm) return item;
    }
    return null;
  }

  static BankItem bestMatch(String query) {
    final text = _normalize(query);
    if (text.isEmpty) return other;

    // Direct ID match
    for (final item in items) {
      if (item.id == text) return item;
    }

    // Direct name match
    for (final item in items) {
      if (_normalize(item.name) == text) return item;
    }

    // Alias matches
    BankItem? bestItem;
    int longestAlias = 0;

    for (final item in items) {
      if (item.isCustom) continue;
      for (final alias in item.aliases) {
        final normAlias = _normalize(alias);
        if (text == normAlias || text.contains(normAlias) || normAlias.contains(text)) {
          if (normAlias.length > longestAlias) {
            longestAlias = normAlias.length;
            bestItem = item;
          }
        }
      }
    }

    return bestItem ?? other;
  }

  static String _normalize(String value) {
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    final lower = value.toLowerCase().trim();
    return lower.split('').map((c) => accents[c] ?? c).join().replaceAll(RegExp(r'\s+'), ' ');
  }
}
