import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/auth_service.dart';
import 'package:mobile/core/schedule_service.dart';
import 'package:mobile/schedule_screen.dart';
import 'package:mobile/widgets/wheel_time_picker.dart';

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
  test('Update assignment sends PUT to the scheduling API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/shift-assignments/1');
      expect(request.headers['Authorization'], 'Bearer test-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['shiftName'], 'Ca tối mới');
      expect(body['startTime'], '21:00');
      expect(body['endTime'], '05:00');
      expect(body['isOvernight'], true);
      return http.Response.bytes(utf8.encode(jsonEncode(shiftJson())), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final result = await ScheduleService.updateAssignment(
      assignmentId: 1,
      shiftName: 'Ca tối mới',
      startTime: '21:00',
      endTime: '05:00',
      isOvernight: true,
      client: client,
    );
    expect(result.assignmentId, 1);
    client.close();
  });
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
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
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
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
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
  testWidgets('Manager role shows Phân ca mới button while Employee does not', (
    tester,
  ) async {
    // 1. Employee role
    AuthService.currentUser = UserModel(
      id: 101,
      email: 'employee@test.vn',
      displayName: 'Nhân viên',
      role: 'Employee',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShiftScheduleScreen(
          loadSchedule: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thao tác phân ca'), findsNothing);

    // 2. Manager role
    AuthService.currentUser = UserModel(
      id: 102,
      email: 'manager@test.vn',
      displayName: 'Quản lý',
      role: 'Manager',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShiftScheduleScreen(
          loadSchedule: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thao tác phân ca'), findsOneWidget);
  });
  testWidgets('Shift card displays employee name for manager overview', (
    tester,
  ) async {
    AuthService.currentUser = UserModel(
      id: 102,
      email: 'manager@test.vn',
      displayName: 'Quản lý',
      role: 'Manager',
    );
    final shiftWithEmp = ScheduleShift(
      assignmentId: 99,
      employeeId: 55,
      employeeName: 'Nguyễn Văn A',
      employeeCode: 'NV-0055',
      departmentName: 'Bán hàng',
      name: 'Ca sáng',
      date: scheduleDate(scheduleToday()),
      startTime: '08:00',
      endTime: '17:00',
      isOvernight: false,
      status: 'Approved',
      color: '#f59e0b',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShiftScheduleScreen(
          loadSchedule: (_, _) async => [shiftWithEmp],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Ca sáng'), findsOneWidget);
    expect(find.text('08:00 – 17:00'), findsOneWidget);
  });
  testWidgets('24-Hour Wheel Picker modal displays 24H badge and initial time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => show24HourWheelTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 14, minute: 30),
              ),
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    expect(find.text('24H'), findsOneWidget);
    expect(find.text('14'), findsWidgets);
    expect(find.text('30'), findsWidgets);
    expect(find.text('GIỜ (0 - 23)'), findsOneWidget);
    expect(find.text('PHÚT (00 - 59)'), findsOneWidget);
  });
}

