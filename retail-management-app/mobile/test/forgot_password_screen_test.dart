import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/forgot_password_screen.dart';

void main() {
  testWidgets('shows the email step first', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    expect(find.text('Quên mật khẩu'), findsWidgets);
    expect(find.byKey(const Key('forgot-email-field')), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
  });

  testWidgets('validates an empty email before sending', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
  });
}
