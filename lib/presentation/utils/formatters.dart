import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static final _copFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static String cop(int amount) {
    return _copFormat.format(amount);
  }

  static String date(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String dayAndMonth(DateTime date) {
    return DateFormat('d MMMM', 'es').format(date);
  }
}
