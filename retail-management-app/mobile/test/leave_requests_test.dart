import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/leave_requests_screen.dart';
import 'package:mobile/core/leave_request_service.dart';
import 'package:mobile/core/schedule_service.dart';

void main() {
  testWidgets('Short reason blocks preview before sending a request', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateLeaveScreen()));
    await tester.enterText(find.byType(TextFormField).first, 'abc');
    await tester.ensureVisible(find.text('Xem trước tác động'));
    await tester.tap(find.text('Xem trước tác động'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập ít nhất 10 ký tự.'), findsOneWidget);
    expect(find.text('Gửi đơn chờ Admin duyệt'), findsNothing);
  });

  testWidgets('Date range and emergency reveal their required inputs', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateLeaveScreen()));
    await tester.tap(find.text('Một ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhiều ngày').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Đến ngày:'), findsOneWidget);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Giải thích nộp bổ sung'), findsOneWidget);
  });

  test('Approved leave displays as leave rather than available work', () {
    final shift = ScheduleShift.fromJson({
      'assignmentId': 1,
      'employeeId': 101,
      'isOnLeave': true,
    });
    expect(shift.statusLabel, 'Đã duyệt nghỉ phép');
    final preview = LeavePreviewModel.fromJson({
      'previewToken': 'token',
      'hasConflict': true,
      'conflictReason': 'Trùng đơn',
      'scheduledLeaveMinutes': 0,
      'scheduleBasis': 'Missing',
      'effectiveIntervals': [
        {'startLocal': '2026-11-02 22:00', 'endLocal': '2026-11-04 00:00'},
      ],
    });
    expect(preview.hasConflict, isTrue);
    expect(preview.scheduleBasis, 'Missing');
    expect(preview.effectiveIntervals, hasLength(1));
  });
}
