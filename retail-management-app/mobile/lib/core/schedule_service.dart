import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

DateTime scheduleToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime.utc(now.year, now.month, now.day);
}

String scheduleDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ScheduleShift {
  final int assignmentId;
  final int employeeId;
  final String name;
  final String date;
  final String startTime;
  final String endTime;
  final bool isOvernight;
  final String status;
  final String color;
  final String? note;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  const ScheduleShift({
    required this.assignmentId,
    required this.employeeId,
    required this.name,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isOvernight,
    required this.status,
    required this.color,
    this.note,
    this.checkInAt,
    this.checkOutAt,
  });

  factory ScheduleShift.fromJson(Map<String, dynamic> json) {
    final attendance = json['attendance'] as Map<String, dynamic>?;
    return ScheduleShift(
      assignmentId: (json['assignmentId'] as num).toInt(),
      employeeId: (json['employeeId'] as num).toInt(),
      name: json['shiftName'] as String,
      date: json['shiftDate'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      isOvernight: json['isOvernight'] == true,
      status: json['status'] as String? ?? 'Approved',
      color: json['color'] as String? ?? '#e96900',
      note: json['note'] as String?,
      checkInAt: DateTime.tryParse(attendance?['checkInAt'] as String? ?? ''),
      checkOutAt: DateTime.tryParse(attendance?['checkOutAt'] as String? ?? ''),
    );
  }

  String get statusLabel => status == 'Cancelled'
      ? 'Đã hủy'
      : checkOutAt != null
      ? 'Đã hoàn thành'
      : checkInAt != null
      ? 'Đang làm việc'
      : 'Chưa vào ca';
}

class ScheduleService {
  static Future<List<ScheduleShift>> getSchedule(
    DateTime start,
    DateTime end, {
    http.Client? client,
  }) async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/shift-assignments/schedule')
        .replace(
          queryParameters: {
            'startDate': scheduleDate(start),
            'endDate': scheduleDate(end),
            'employeeId': '$userId',
          },
        );
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.get(uri, headers: {'Authorization': 'Bearer $token'})
                  : http.get(uri, headers: {'Authorization': 'Bearer $token'}))
              .timeout(const Duration(seconds: 15)),
    );
    Map<String, dynamic>? payload;
    try {
      payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      /* Handle non-JSON server errors below. */
    }
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw Exception(
          'API lịch làm việc không tồn tại tại máy chủ này (404): $uri. '
          'Kiểm tra API_BASE_URL và triển khai phiên bản Manage365 có route '
          '/api/shift-assignments/schedule.',
        );
      }
      throw Exception(
        payload?['title'] ??
            (response.statusCode == 401
                ? 'Phiên đăng nhập đã hết hạn.'
                : 'Không tải được lịch làm việc (${response.statusCode}).'),
      );
    }
    if (payload?['assignments'] is! List) {
      throw Exception('Dữ liệu lịch làm việc không hợp lệ.');
    }
    final shifts = (payload!['assignments'] as List)
        .map((item) => ScheduleShift.fromJson(item as Map<String, dynamic>))
        .where(
          (shift) => shift.status != 'Cancelled' && shift.employeeId == userId,
        )
        .toList();
    shifts.sort(
      (a, b) =>
          '${a.date} ${a.startTime}'.compareTo('${b.date} ${b.startTime}'),
    );
    return shifts;
  }
}
