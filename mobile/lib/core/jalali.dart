/// Compact Jalali (Persian calendar) formatting for user-visible dates/times.
/// No external package — algorithm matches common civil conversions.
class JalaliFmt {
  JalaliFmt._();

  static String format(
    Object? raw, {
    bool withTime = true,
    String empty = '—',
  }) {
    final dt = _parse(raw);
    if (dt == null) {
      final s = '$raw'.trim();
      return s.isEmpty ? empty : s;
    }
    final local = dt.toLocal();
    final j = _toJalali(local.year, local.month, local.day);
    final date =
        '${j[0]}/${_two(j[1])}/${_two(j[2])}';
    if (!withTime) return date;
    return '$date ${_two(local.hour)}:${_two(local.minute)}';
  }

  static DateTime? _parse(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = '$raw'.trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Gregorian → Jalali [jy, jm, jd]
  static List<int> _toJalali(int gy, int gm, int gd) {
    final gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    var gy2 = (gm > 2) ? (gy + 1) : gy;
    var days = 355666 +
        (365 * gy) +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) +
        gd +
        gdm[gm - 1];
    var jy = -1595 + (33 * (days ~/ 12053));
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    late int jm;
    late int jd;
    if (days < 186) {
      jm = 1 + (days ~/ 31);
      jd = 1 + (days % 31);
    } else {
      jm = 7 + ((days - 186) ~/ 30);
      jd = 1 + ((days - 186) % 30);
    }
    return [jy, jm, jd];
  }
}
