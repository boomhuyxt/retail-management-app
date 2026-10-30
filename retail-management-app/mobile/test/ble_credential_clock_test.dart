import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ble_attendance_service.dart';

void main() {
  test('valid server lease survives phone clock three minutes ahead', () {
    final credential = BleCredential('id', 'token',
        DateTime.now().subtract(const Duration(minutes: 1)),
        const Duration(seconds: 118));
    expect(credential.expiresWithin(const Duration(seconds: 15)), isFalse);
    expect(credential.expiresWithin(const Duration(seconds: 65)), isFalse);
  });

  test('expired lease is rejected even with phone clock behind server', () {
    final credential = BleCredential('id', 'token',
        DateTime.now().add(const Duration(minutes: 3)), Duration.zero);
    expect(credential.expiresWithin(const Duration(seconds: 15)), isTrue);
  });

  test('renewal margin leaves time for kiosk to observe new credential', () {
    final credential = BleCredential('id', 'token', DateTime.now(),
        const Duration(seconds: 60));
    expect(credential.expiresWithin(const Duration(seconds: 65)), isTrue);
    expect(credential.expiresWithin(const Duration(seconds: 15)), isFalse);
  });
}
