import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/input_validators.dart';

void main() {
  group('InputValidators.email', () {
    test('rejects the invalid email reported by the tester', () {
      expect(
        InputValidators.email(
          'dangkhoa.retail',
          requiredMessage: 'Email bắt buộc',
        ),
        'Email không đúng định dạng',
      );
    });

    test('rejects empty values with the requested message', () {
      expect(
        InputValidators.email('  ', requiredMessage: 'Email bắt buộc'),
        'Email bắt buộc',
      );
    });

    test('accepts a valid trimmed email', () {
      expect(
        InputValidators.email(
          ' employee@retail365.com ',
          requiredMessage: 'Email bắt buộc',
        ),
        isNull,
      );
    });
  });
}
