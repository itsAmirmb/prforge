import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/utils/spoken_numbers.dart';

void main() {
  test('whole numbers in Persian words', () {
    expect(persianInt(0), 'صفر');
    expect(persianInt(10), 'ده');
    expect(persianInt(25), 'بیست و پنج');
    expect(persianInt(60), 'شصت');
    expect(persianInt(105), 'صد و پنج');
    expect(persianInt(1000), 'هزار');
  });

  test('weights: half, decimals and whole', () {
    expect(persianWeight(12.5), 'دوازده و نیم');
    expect(persianWeight(0.5), 'نیم');
    expect(persianWeight(12.25), 'دوازده ممیز بیست و پنج');
    expect(persianWeight(12.05), 'دوازده ممیز صفر پنج');
    expect(persianWeight(60), 'شصت');
  });

  test('English weights spell out the point', () {
    expect(englishWeight(12.5), '12 point 5');
    expect(englishWeight(12.25), '12 point 2 5');
    expect(englishWeight(60), '60');
  });
}
