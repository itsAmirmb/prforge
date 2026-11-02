import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/programs/domain/rep_scheme.dart';

void main() {
  group('parseRepScheme / formatRepScheme', () {
    test('round trip', () {
      expect(parseRepScheme('12,10,8,8'), [12, 10, 8, 8]);
      expect(formatRepScheme([12, 10, 8, 8]), '12,10,8,8');
      expect(parseRepScheme(formatRepScheme([5])), [5]);
    });

    test('tolerates spaces', () => expect(parseRepScheme(' 12 , 10 '), [12, 10]));

    test('empty or invalid gives null', () {
      expect(parseRepScheme(null), isNull);
      expect(parseRepScheme(''), isNull);
      expect(parseRepScheme('12,,8'), isNull);
      expect(parseRepScheme('12,0'), isNull);
      expect(parseRepScheme('12,x'), isNull);
      expect(parseRepScheme('-3'), isNull);
      expect(formatRepScheme(null), isNull);
      expect(formatRepScheme([]), isNull);
    });

    test('isValidRepScheme', () {
      expect(isValidRepScheme([1, 2]), isTrue);
      expect(isValidRepScheme([]), isFalse);
      expect(isValidRepScheme([3, 0]), isFalse);
    });
  });

  group('parseRepsInput', () {
    test('single number and list', () {
      expect(parseRepsInput('10'), [10]);
      expect(parseRepsInput('12, 10, 8, 8'), [12, 10, 8, 8]);
    });

    test('Persian and Arabic digits and commas', () {
      expect(parseRepsInput('۱۲، ۱۰، ۸'), [12, 10, 8]);
      expect(parseRepsInput('١٢,١٠'), [12, 10]);
    });

    test('empty or invalid gives null', () {
      expect(parseRepsInput(''), isNull);
      expect(parseRepsInput('  '), isNull);
      expect(parseRepsInput('abc'), isNull);
      expect(parseRepsInput('10,'), isNull);
    });
  });

  group('repsForSet', () {
    test('uses the scheme, then repeats its last value', () {
      const scheme = [12, 10, 8];
      expect(repsForSet(0, scheme: scheme), 12);
      expect(repsForSet(2, scheme: scheme), 8);
      expect(repsForSet(3, scheme: scheme), 8);
      expect(repsForSet(9, scheme: scheme, fallback: 5), 8);
    });

    test('falls back to the plain target without a scheme', () {
      expect(repsForSet(0, fallback: 10), 10);
      expect(repsForSet(2, scheme: const [], fallback: 10), 10);
      expect(repsForSet(0), isNull);
    });
  });
}
