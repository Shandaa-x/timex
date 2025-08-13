class HolidayUtils {
  // Define holidays for Mongolia (you can modify this based on your needs)
  static final Map<String, String> _holidays = {
    '01-01': 'Шинэ жил',
    '02-12': 'Цагаан сар', // This varies each year, adjust accordingly
    '03-08': 'Эмэгтэйчүүдийн өдөр',
    '06-01': 'Хүүхдийн өдөр',
    '07-11': 'Нaaдам', // First day of Naadam
    '07-12': 'Нaaдам', // Second day of Naadam
    '07-13': 'Нaaдам', // Third day of Naadam
    '11-26': 'Тусгаар тогтнолын өдөр',
    '12-29': 'Тусгаар тогтнолын өдөр', // Extended holiday
  };

  static bool isHoliday(DateTime date) {
    final key = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Check if it's a defined holiday
    if (_holidays.containsKey(key)) {
      return true;
    }

    // Check if it's a weekend (Saturday = 6, Sunday = 7)
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }

    return false;
  }

  static String? getHolidayName(DateTime date) {
    final key = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    if (_holidays.containsKey(key)) {
      return _holidays[key];
    }

    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return 'Амралтын өдөр';
    }

    return null;
  }
}