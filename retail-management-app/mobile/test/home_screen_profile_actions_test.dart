import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/auth_service.dart';
import 'package:mobile/home_screen.dart';

void main() {
  setUp(() {
    AuthService.currentUser = UserModel(
      id: 15,
      email: 'staff@example.com',
      displayName: 'Nhân viên kiểm thử',
      role: 'Employee',
    );
  });

  testWidgets('support item shows the requested contact information', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.ensureVisible(find.text('Trợ giúp & Hỗ trợ'));
    await tester.tap(find.text('Trợ giúp & Hỗ trợ'));
    await tester.pumpAndSettle();

    expect(find.text('Đội ngũ Retail365 sẵn sàng hỗ trợ bạn'), findsOneWidget);
    expect(
      find.text('Mọi vấn đề về kỹ thuật và hỗ trợ, vui lòng liên hệ:'),
      findsOneWidget,
    );
    expect(find.text('reretailmanagement@gmail.com'), findsOneWidget);
    expect(find.text('0916887224'), findsOneWidget);
    expect(find.byTooltip('Sao chép Email hỗ trợ'), findsOneWidget);
    final emailText = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == 'reretailmanagement@gmail.com',
      ),
    );
    expect(emailText.maxLines, 1);
  });

  testWidgets('change password starts email verification for signed-in user', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.ensureVisible(find.text('Đổi mật khẩu'));
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('forgot-email-field')),
    );
    expect(emailField.controller?.text, 'staff@example.com');
  });

  testWidgets('manager opens the all-employee attendance history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = UserModel(
      id: 18,
      email: 'manager@example.com',
      displayName: 'Quản lý',
      role: 'Manager',
    );
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.ensureVisible(find.text('Lịch sử chấm công'));
    await tester.tap(find.text('Lịch sử chấm công'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử chấm công nhân viên'), findsOneWidget);
    expect(find.text('Theo ngày'), findsOneWidget);
    expect(find.text('Theo tháng'), findsOneWidget);
  });
}
