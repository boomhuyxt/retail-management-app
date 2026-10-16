import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/auth_service.dart';
import 'package:mobile/core/schedule_service.dart';
import 'package:mobile/schedule_screen.dart';

Map<String, dynamic> shiftJson({
  int id = 1,
  String? date,
  Map<String, dynamic>? attendance,
  String status = 'Approved',
  int employeeId = 101,
}) => {
  'assignmentId': id,
  'employeeId': employeeId,
  'shiftName': 'Ca tối',
  'shiftDate': date ?? scheduleDate(scheduleToday()),
  'startTime': '22:00',
  'endTime': '06:00',
  'isOvernight': true,
  'status': status,
  'color': '#8b5cf6',
  'attendance': attendance,
};

void main() {
  setUp(() {
    AuthService.currentUser = UserModel(
      id: 101,
      email: 'test@example.invalid',
      displayName: 'Test',
      role: 'Employee',
    );
    AuthService.currentToken = 'test-token';
    AuthService.tokenExpiresAt = DateTime.now().add(const Duration(hours: 1));
  });
  test('Assignment DTO keeps ID, overnight and not-started status', () {
    final shift = ScheduleShift.fromJson(shiftJson());
    expect(shift.assignmentId, 1);
    expect(shift.isOvernight, true);
    expect(shift.statusLabel, 'Chưa vào ca');
    expect(
      ScheduleShift.fromJson(
        shiftJson(attendance: {'checkInAt': '2026-10-15T15:00:00Z'}),
      ).statusLabel,
      'Đang làm việc',
    );
    expect(
      ScheduleShift.fromJson(
        shiftJson(
          attendance: {
            'checkInAt': '2026-10-15T15:00:00Z',
            'checkOutAt': '2026-10-15T23:00:00Z',
          },
        ),
      ).statusLabel,
      'Đã hoàn thành',
    );
  });
  test(
    'Schedule service calls assignments API with own user and week',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/shift-assignments/schedule');
        expect(request.url.queryParameters, {
          'startDate': '2026-10-12',
          'endDate': '2026-10-18',
          'employeeId': '101',
        });
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'assignments': [
              shiftJson(),
              shiftJson(id: 2, status: 'Cancelled'),
              shiftJson(id: 3, employeeId: 102),
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final result = await ScheduleService.getSchedule(
        DateTime.utc(2026, 10, 12),
        DateTime.utc(2026, 10, 18),
        client: client,
      );
      expect(result.map((s) => s.assignmentId), [1]);
      client.close();
    },
  );
  test('API errors are surfaced instead of an empty schedule', () async {
    final client = MockClient(
      (_) async => http.Response('{"title":"Unavailable"}', 503),
    );
    await expectLater(
      ScheduleService.getSchedule(
        DateTime.utc(2026, 10, 12),
        DateTime.utc(2026, 10, 18),
        client: client,
      ),
      throwsException,
    );
    client.close();
  });
  test(
    '404 identifies the missing schedule endpoint and configured URL',
    () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      await expectLater(
        ScheduleService.getSchedule(
          DateTime.utc(2026, 10, 12),
          DateTime.utc(2026, 10, 18),
          client: client,
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains('/api/shift-assignments/schedule'),
              contains('API_BASE_URL'),
            ),
          ),
        ),
      );
      client.close();
    },
  );
  testWidgets(
    'Shows future assignment without attendance and refreshes after cancellation',
    (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ShiftScheduleScreen(
            loadSchedule: (_, _) async =>
                cancelled ? [] : [ScheduleShift.fromJson(shiftJson())],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ca tối'), findsOneWidget);
      expect(find.text('Chưa vào ca'), findsOneWidget);
      expect(find.textContaining('kết thúc ngày hôm sau'), findsOneWidget);
      cancelled = true;
      await tester.tap(find.byTooltip('Tải lại lịch'));
      await tester.pumpAndSettle();
      expect(find.text('Ca tối'), findsNothing);
      expect(find.text('Chưa được phân ca trong ngày này.'), findsOneWidget);
    },
  );
  testWidgets('Network error exposes retry and recovers', (tester) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ShiftScheduleScreen(
          loadSchedule: (_, _) async {
            if (fail) throw Exception('Lỗi mạng');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lỗi mạng'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Lỗi mạng'), findsNothing);
    expect(find.text('Chưa được phân ca trong ngày này.'), findsOneWidget);
  });
  testWidgets('Late previous-week response cannot replace current week', (
    tester,
  ) async {
    final old = Completer<List<ScheduleShift>>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShiftScheduleScreen(
          loadSchedule: (_, _) {
            calls++;
            return calls == 1 ? old.future : Future.value([]);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    old.complete([
      ScheduleShift.fromJson(
        shiftJson(
          date: scheduleDate(scheduleToday().add(const Duration(days: 7))),
        ),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Ca tối'), findsNothing);
  });
}
