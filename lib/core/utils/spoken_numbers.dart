import 'format.dart';

const _ones = [
  'صفر', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه', 'ده',
  'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده',
  'نوزده', //
];
const _tens = [
  '', '', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود', //
];
const _hundreds = [
  '', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد',
  'نهصد', //
];

/// A whole number in Persian words, e.g. 25 -> "بیست و پنج". Up to 999 999;
/// anything larger is returned as digits.
String persianInt(int n) {
  if (n < 0) return 'منفی ${persianInt(-n)}';
  if (n < 20) return _ones[n];
  if (n < 100) {
    final o = n % 10;
    return o == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} و ${_ones[o]}';
  }
  if (n < 1000) {
    final r = n % 100;
    return r == 0
        ? _hundreds[n ~/ 100]
        : '${_hundreds[n ~/ 100]} و ${persianInt(r)}';
  }
  if (n < 1000000) {
    final th = n ~/ 1000;
    final head = th == 1 ? 'هزار' : '${persianInt(th)} هزار';
    final r = n % 1000;
    return r == 0 ? head : '$head و ${persianInt(r)}';
  }
  return n.toString();
}

/// A weight in Persian words so no speech engine has to guess how to read a
/// decimal point: 12.5 -> "دوازده و نیم", 12.25 -> "دوازده ممیز بیست و پنج".
String persianWeight(double kg) {
  final parts = (formatWeight(kg) ?? '').split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return formatWeight(kg) ?? '';
  if (parts.length == 1) return persianInt(whole);
  final frac = parts[1];
  if (frac == '5') return whole == 0 ? 'نیم' : '${persianInt(whole)} و نیم';
  final fraction = frac.startsWith('0') || frac.length > 3
      ? frac.split('').map((d) => _ones[int.parse(d)]).join(' ')
      : persianInt(int.parse(frac));
  return '${persianInt(whole)} ممیز $fraction';
}

/// A weight for the English voice: 12.5 -> "12 point 5" (digits after the
/// point are read one by one, "12 point 2 5").
String englishWeight(double kg) {
  final parts = (formatWeight(kg) ?? '').split('.');
  if (parts.length != 2) return parts.first;
  return '${parts.first} point ${parts[1].split('').join(' ')}';
}
