class AppDateUtils {
  const AppDateUtils._();

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static String monthYearLabel(DateTime date) {
    return '${_monthNames[date.month - 1]} de ${date.year}';
  }

  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month);
  }

  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }
}
