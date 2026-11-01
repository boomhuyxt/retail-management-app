import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_config.dart';
import 'package:mobile/core/auth_service.dart';
import 'package:mobile/core/chatbot_service.dart';
import 'package:mobile/core/schedule_service.dart';
import 'package:mobile/chatbot_screen.dart';
import 'package:mobile/widgets/chatbot_bubble.dart';

void main() {
  setUp(() {
    AuthService.currentUser = UserModel(
      id: 99,
      email: 'admin@manage365.vn',
      displayName: 'Admin Quản Trị',
      role: 'Admin',
    );
    AuthService.currentToken = 'valid-jwt-token';
    AuthService.tokenExpiresAt = DateTime.now().add(const Duration(hours: 2));
  });

  group('ChatbotService Unit Tests', () {
    test('sendMessage sends correct payload and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), ApiConfig.chatbotChatUrl);
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer valid-jwt-token');

        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['message'], 'Xin chào');
        expect(payload['history'], isNotNull);

        return http.Response(
          jsonEncode({
            'success': true,
            'reply': 'Chào bạn! Tôi là Trợ lý AI Manage365.',
            'model': 'Manage365-AI-Engine',
            'timestamp': '2026-11-01T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final history = [
        ChatMessageItem(role: 'user', text: 'Chào bot'),
        ChatMessageItem(role: 'assistant', text: 'Xin chào!'),
      ];

      final reply = await ChatbotService.sendMessage(
        message: 'Xin chào',
        history: history,
        client: mockClient,
      );

      expect(reply.success, isTrue);
      expect(reply.reply, 'Chào bạn! Tôi là Trợ lý AI Manage365.');
      expect(reply.model, 'Manage365-AI-Engine');
    });

    test('getTemplates parses HR templates list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), ApiConfig.chatbotTemplatesUrl);
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'templates': [
              {
                'id': 'BM-01',
                'code': 'BM-01',
                'title': 'Mẫu Đơn xin Nghỉ phép',
                'sampleText': 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM...',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final templates = await ChatbotService.getTemplates(client: mockClient);
      expect(templates.length, 1);
      expect(templates.first.code, 'BM-01');
      expect(templates.first.title, 'Mẫu Đơn xin Nghỉ phép');
    });

    test('checkHealth returns true when service is online', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'online',
            'service': 'HR Support Assistant AI',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final isOnline = await ChatbotService.checkHealth(client: mockClient);
      expect(isOnline, isTrue);
    });
  });

  group('ScheduleService AI Scheduling Unit Tests', () {
    test('generateAiSchedule sends request and parses proposed shifts', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), ApiConfig.aiScheduleGenerateUrl);
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer valid-jwt-token');

        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['weekStartDate'], '2026-11-02');
        expect(payload['minEmployeesPerShift'], 2);
        expect(payload['maxShiftsPerEmployeePerWeek'], 6);

        return http.Response(
          jsonEncode({
            'weekStartDate': '2026-11-02',
            'weekEndDate': '2026-11-08',
            'proposedShiftCount': 2,
            'totalEmployeesConsidered': 5,
            'employeesAssigned': 5,
            'averageShiftsPerEmployee': 2.5,
            'proposedShifts': [
              {
                'employeeId': 101,
                'employeeName': 'Nguyễn Văn A',
                'employeeCode': 'NV-001',
                'shiftDate': '2026-11-02',
                'shiftName': 'Ca sáng',
                'startTime': '08:00',
                'endTime': '16:00',
                'isOvernight': false,
                'color': '#f59e0b',
                'reason': 'Phù hợp định biên',
              },
              {
                'employeeId': 102,
                'employeeName': 'Trần Thị B',
                'employeeCode': 'NV-002',
                'shiftDate': '2026-11-02',
                'shiftName': 'Ca tối',
                'startTime': '16:00',
                'endTime': '23:00',
                'isOvernight': false,
                'color': '#8b5cf6',
                'reason': 'Phù hợp định biên',
              },
            ],
            'batchAssignmentPayload': [
              {
                'employeeId': 101,
                'shiftDate': '2026-11-02',
                'customShiftName': 'Ca sáng',
                'customStartTime': '08:00',
                'customEndTime': '16:00',
              },
            ],
            'aiInsights': ['Phân bổ đồng đều nhân sự cho tuần mới.'],
            'warnings': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await ScheduleService.generateAiSchedule(
        const AiScheduleRequest(
          weekStartDate: '2026-11-02',
          minEmployeesPerShift: 2,
          maxShiftsPerEmployeePerWeek: 6,
        ),
        client: mockClient,
      );

      expect(result.proposedShiftCount, 2);
      expect(result.totalEmployeesConsidered, 5);
      expect(result.proposedShifts.length, 2);
      expect(result.proposedShifts.first.employeeName, 'Nguyễn Văn A');
      expect(result.proposedShifts.first.startTime, '08:00');
      expect(result.batchAssignmentPayload.length, 1);
      expect(result.aiInsights.first, contains('Phân bổ đồng đều'));
    });

    test('applyBatchShifts calls batch endpoint with payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), ApiConfig.batchAssignShiftsUrl);
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer valid-jwt-token');

        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['assignments'], isList);

        return http.Response(
          jsonEncode({
            'assignedCount': 10,
            'message': 'Phân ca hàng loạt thành công',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final count = await ScheduleService.applyBatchShifts(
        [
          {'employeeId': 101, 'shiftDate': '2026-11-02'},
        ],
        client: mockClient,
      );

      expect(count, 10);
    });
    test('deleteShift falls back to PUT Cancelled when DELETE returns 400', () async {
      int deleteCalls = 0;
      int putCalls = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE') {
          deleteCalls++;
          return http.Response(
            jsonEncode({'title': 'Chọn cửa hàng phụ trách ca làm.', 'status': 400}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.method == 'PUT') {
          putCalls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['status'], 'Cancelled');
          expect(body['shopOwnerId'], 5);
          return http.Response(
            jsonEncode({'assignmentId': 99, 'status': 'Cancelled'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      await expectLater(
        ScheduleService.deleteShift(99, shopOwnerId: 5, client: mockClient),
        completes,
      );
      expect(deleteCalls, 1);
      expect(putCalls, 1);
    });

    test('deleteShift surfaces server ProblemDetails message when both fail', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'title': 'Ca đã có chấm công; không được sửa hoặc hủy để giữ nguyên lịch sử.',
            'status': 400,
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () => ScheduleService.deleteShift(99, shopOwnerId: 5, client: mockClient),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('Ca đã có chấm công'),
          ),
        ),
      );
    });
  });

  group('ChatbotFloatingBubble Widget Tests', () {
    testWidgets('ChatbotFloatingBubble renders icon and badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ChatbotFloatingBubble(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ChatbotFloatingBubble), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
    });
  });

  group('ChatbotScreen UI Widget Tests', () {
    testWidgets('ChatbotScreen displays welcoming header and suggested prompts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatbotScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trợ lý AI Manage365'), findsOneWidget);
      expect(find.textContaining('Admin Quản Trị'), findsOneWidget);
      expect(find.textContaining('Chế độ Quản trị & Phân ca AI'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
