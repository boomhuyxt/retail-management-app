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

class StaffEmployee {
  final int id;
  final String code;
  final String displayName;
  final String status;
  final String? departmentName;

  const StaffEmployee({
    required this.id,
    required this.code,
    required this.displayName,
    required this.status,
    this.departmentName,
  });

  factory StaffEmployee.fromJson(Map<String, dynamic> json) {
    return StaffEmployee(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? 'NV-${json['id']}',
      displayName: json['displayName'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      departmentName: json['departmentName'] as String?,
    );
  }
}

class ShiftTemplateModel {
  final int id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final bool isOvernight;
  final String color;
  final String? description;

  const ShiftTemplateModel({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.isOvernight,
    required this.color,
    this.description,
  });

  factory ShiftTemplateModel.fromJson(Map<String, dynamic> json) {
    return ShiftTemplateModel(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '06:00',
      endTime: json['endTime'] as String? ?? '14:00',
      isOvernight: json['isOvernight'] == true,
      color: json['color'] as String? ?? '#f59e0b',
      description: json['description'] as String?,
    );
  }
}

class ShiftConflictResult {
  final bool hasConflict;
  final String conflictType;
  final String message;
  final List<String> warnings;

  const ShiftConflictResult({
    required this.hasConflict,
    required this.conflictType,
    required this.message,
    required this.warnings,
  });

  factory ShiftConflictResult.fromJson(Map<String, dynamic> json) {
    return ShiftConflictResult(
      hasConflict: json['hasConflict'] == true,
      conflictType: json['conflictType'] as String? ?? 'NONE',
      message: json['message'] as String? ?? '',
      warnings: (json['warnings'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ScheduleShift {
  final int assignmentId;
  final int employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String? departmentName;
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
  final bool isOnLeave;
  final String? leaveStatus;

  const ScheduleShift({
    required this.assignmentId,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.departmentName,
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
    this.isOnLeave = false,
    this.leaveStatus,
  });

  factory ScheduleShift.fromJson(Map<String, dynamic> json) {
    final attendance = json['attendance'] as Map<String, dynamic>?;
    return ScheduleShift(
      assignmentId: (json['assignmentId'] as num).toInt(),
      employeeId: (json['employeeId'] as num).toInt(),
      employeeName: json['employeeName'] as String?,
      employeeCode: json['employeeCode'] as String?,
      departmentName: json['departmentName'] as String?,
      name: (json['shiftName'] as String?) ?? 'Ca làm',
      date: (json['shiftDate'] as String?) ?? '',
      startTime: (json['startTime'] as String?) ?? '',
      endTime: (json['endTime'] as String?) ?? '',
      isOvernight: json['isOvernight'] == true,
      status: json['status'] as String? ?? 'Approved',
      color: json['color'] as String? ?? '#e96900',
      note: json['note'] as String?,
      checkInAt: DateTime.tryParse(attendance?['checkInAt'] as String? ?? ''),
      checkOutAt: DateTime.tryParse(attendance?['checkOutAt'] as String? ?? ''),
      isOnLeave: json['isOnLeave'] == true,
      leaveStatus: json['leaveStatus'] as String?,
    );
  }

  String get statusLabel => isOnLeave
      ? 'Đã duyệt nghỉ phép'
      : status == 'Cancelled'
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
    int? employeeId,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    final isManager = user.role == 'Admin' || user.role == 'Manager';

    final effectiveEmployeeId = employeeId ?? (!isManager ? user.id : null);

    final queryParams = {
      'startDate': scheduleDate(start),
      'endDate': scheduleDate(end),
    };
    if (effectiveEmployeeId != null) {
      queryParams['employeeId'] = '$effectiveEmployeeId';
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/shift-assignments/schedule',
    ).replace(queryParameters: queryParams);

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
          (shift) =>
              shift.status != 'Cancelled' &&
              (effectiveEmployeeId == null ||
                  shift.employeeId == effectiveEmployeeId),
        )
        .toList();
    shifts.sort(
      (a, b) =>
          '${a.date} ${a.startTime}'.compareTo('${b.date} ${b.startTime}'),
    );
    return shifts;
  }

  static Future<List<StaffEmployee>> getEmployees({http.Client? client}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/shift-assignments/employees?page=1&pageSize=100',
    );
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.get(uri, headers: {'Authorization': 'Bearer $token'})
                  : http.get(uri, headers: {'Authorization': 'Bearer $token'}))
              // The same employee endpoint also performs a total-count query. Give
              // slower development databases enough time to respond on mobile.
              .timeout(const Duration(seconds: 30)),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được danh sách nhân viên (${response.statusCode}).',
      );
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = payload['items'] as List? ?? [];
    return items
        .map((e) => StaffEmployee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ShiftTemplateModel>> getTemplates({
    http.Client? client,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/shift-templates');
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.get(uri, headers: {'Authorization': 'Bearer $token'})
                  : http.get(uri, headers: {'Authorization': 'Bearer $token'}))
              .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được danh sách mẫu ca (${response.statusCode}).',
      );
    }
    final items = jsonDecode(utf8.decode(response.bodyBytes)) as List? ?? [];
    return items
        .map((e) => ShiftTemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ShiftConflictResult> validateConflict({
    required int employeeId,
    required String shiftDate,
    required String startTime,
    required String endTime,
    required bool isOvernight,
    int? excludeAssignmentId,
    http.Client? client,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/shift-assignments/validate',
    );
    final body = jsonEncode({
      'employeeId': employeeId,
      'shiftDate': shiftDate,
      'startTime': startTime,
      'endTime': endTime,
      'isOvernight': isOvernight,
      'excludeAssignmentId': excludeAssignmentId,
    });
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.post(
                      uri,
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: body,
                    )
                  : http.post(
                      uri,
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: body,
                    ))
              .timeout(const Duration(seconds: 15)),
    );
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ShiftConflictResult.fromJson(payload);
  }

  static Future<ScheduleShift> assignShift({
    required int employeeId,
    required String shiftDate,
    int? shiftTemplateId,
    String? customShiftName,
    String? customStartTime,
    String? customEndTime,
    bool? isOvernight,
    String? note,
    http.Client? client,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/shift-assignments');
    final Map<String, dynamic> bodyData = {
      'employeeId': employeeId,
      'shiftDate': shiftDate,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    if (shiftTemplateId != null) {
      bodyData['shiftTemplateId'] = shiftTemplateId;
    } else {
      bodyData['customShiftName'] =
          (customShiftName != null && customShiftName.trim().isNotEmpty)
          ? customShiftName.trim()
          : 'Ca tùy chỉnh';
      bodyData['customStartTime'] = customStartTime;
      bodyData['customEndTime'] = customEndTime;
      bodyData['isOvernight'] = isOvernight ?? false;
    }
    final body = jsonEncode(bodyData);
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.post(
                      uri,
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: body,
                    )
                  : http.post(
                      uri,
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: body,
                    ))
              .timeout(const Duration(seconds: 15)),
    );
    Map<String, dynamic>? payload;
    try {
      payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode != 201) {
      throw Exception(
        payload?['title'] ?? 'Lỗi khi tạo ca làm (${response.statusCode}).',
      );
    }
    return ScheduleShift.fromJson(payload!);
  }

  static Future<void> deleteShift(
    int assignmentId, {
    http.Client? client,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/shift-assignments/$assignmentId',
    );
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.delete(
                      uri,
                      headers: {'Authorization': 'Bearer $token'},
                    )
                  : http.delete(
                      uri,
                      headers: {'Authorization': 'Bearer $token'},
                    ))
              .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Không thể hủy ca làm (${response.statusCode}).');
    }
  }

  static Future<ScheduleShift> updateAssignment({
    required int assignmentId,
    String? shiftName,
    String? startTime,
    String? endTime,
    bool? isOvernight,
    String? note,
    http.Client? client,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/shift-assignments/$assignmentId',
    );
    final body = jsonEncode({
      if (shiftName != null) 'shiftName': shiftName,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (isOvernight != null) 'isOvernight': isOvernight,
      if (note != null) 'note': note,
    });
    final response = await AuthService.authenticatedRequest(
      (token) =>
          (client != null
                  ? client.put(
                      uri,
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: body,
                    )
                  : http.put(
                      uri,
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: body,
                    ))
              .timeout(const Duration(seconds: 15)),
    );
    Map<String, dynamic>? payload;
    try {
      payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode != 200 || payload == null) {
      throw Exception(
        payload?['title'] ??
            'Không thể cập nhật phân ca (${response.statusCode}).',
      );
    }
    return ScheduleShift.fromJson(payload);
  }
}
