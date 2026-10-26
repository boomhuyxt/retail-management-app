import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'location_service.dart';

class EligibleShiftModel {
  final int? shiftAssignmentId;
  final int? shiftId;
  final String shiftName;
  final String shiftDate;
  final String startTime;
  final String endTime;
  final bool isOvernight;
  final String status; // Assigned, CheckedIn, Completed
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final double? actualHours;
  final String allowedAction; // CHECK_IN, CHECK_OUT, NONE
  final bool canPerformAction;
  final String actionHint;

  EligibleShiftModel({
    required this.shiftAssignmentId,
    required this.shiftId,
    required this.shiftName,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.isOvernight,
    required this.status,
    this.checkInAt,
    this.checkOutAt,
    this.actualHours,
    required this.allowedAction,
    required this.canPerformAction,
    required this.actionHint,
  });

  factory EligibleShiftModel.fromJson(Map<String, dynamic> json) {
    return EligibleShiftModel(
      shiftAssignmentId: _parseNullableInt(json['shiftAssignmentId']),
      shiftId: _parseNullableInt(json['shiftId']),
      shiftName: json['shiftName'] ?? 'Ca làm việc',
      shiftDate: json['shiftDate'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      isOvernight: json['isOvernight'] == true,
      status: json['status'] ?? 'Assigned',
      checkInAt: json['checkInAt'] != null
          ? DateTime.tryParse(json['checkInAt'].toString())?.toLocal()
          : null,
      checkOutAt: json['checkOutAt'] != null
          ? DateTime.tryParse(json['checkOutAt'].toString())?.toLocal()
          : null,
      actualHours: json['actualHours'] != null
          ? double.tryParse(json['actualHours'].toString())
          : null,
      allowedAction: json['allowedAction'] ?? 'NONE',
      canPerformAction: json['canPerformAction'] == true,
      actionHint: json['actionHint'] ?? '',
    );
  }
}

class VerifyQrResult {
  final bool isSuccess;
  final String storeCode;
  final String storeName;
  final String message;
  final List<EligibleShiftModel> eligibleShifts;
  final String? recommendedAction;
  final String? errorCode;

  VerifyQrResult({
    required this.isSuccess,
    required this.storeCode,
    required this.storeName,
    required this.message,
    required this.eligibleShifts,
    this.recommendedAction,
    this.errorCode,
  });
}

class SubmitAttendanceResult {
  final bool isSuccess;
  final String message;
  final int? shiftAssignmentId;
  final String shiftName;
  final String action;
  final DateTime timestamp;
  final double? actualHours;
  final AttendanceProofModel? location;
  final String? errorCode;

  SubmitAttendanceResult({
    required this.isSuccess,
    required this.message,
    required this.shiftAssignmentId,
    required this.shiftName,
    required this.action,
    required this.timestamp,
    this.actualHours,
    this.location,
    this.errorCode,
  });
}

class AttendanceProofModel {
  final String storeCode;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double distanceMeters;
  final double allowedRadiusMeters;
  final bool isMocked;
  final bool isWithinGeofence;

  const AttendanceProofModel({
    required this.storeCode,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.isMocked,
    required this.isWithinGeofence,
  });

  factory AttendanceProofModel.fromJson(Map<String, dynamic> json) {
    return AttendanceProofModel(
      storeCode: json['storeCode']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      accuracyMeters: _parseDouble(json['accuracyMeters']),
      distanceMeters: _parseDouble(json['distanceMeters']),
      allowedRadiusMeters: _parseDouble(json['allowedRadiusMeters']),
      isMocked: json['isMocked'] == true,
      isWithinGeofence: json['isWithinGeofence'] == true,
    );
  }
}

class ShiftRecordModel {
  final int attendanceId;
  final int? shiftAssignmentId;
  final String shiftName;
  final String shiftDate;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final double? actualHours;
  final String status;

  ShiftRecordModel({
    required this.attendanceId,
    required this.shiftAssignmentId,
    required this.shiftName,
    required this.shiftDate,
    required this.checkInAt,
    this.checkOutAt,
    this.actualHours,
    required this.status,
  });

  factory ShiftRecordModel.fromJson(Map<String, dynamic> json) {
    return ShiftRecordModel(
      attendanceId: json['attendanceId'] is int
          ? json['attendanceId']
          : int.tryParse(json['attendanceId'].toString()) ?? 0,
      shiftAssignmentId: _parseNullableInt(json['shiftAssignmentId']),
      shiftName: json['shiftName'] ?? 'Ca làm việc',
      shiftDate: json['shiftDate'] ?? '',
      checkInAt: json['checkInAt'] != null
          ? DateTime.tryParse(json['checkInAt'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      checkOutAt: json['checkOutAt'] != null
          ? DateTime.tryParse(json['checkOutAt'].toString())?.toLocal()
          : null,
      actualHours: json['actualHours'] != null
          ? double.tryParse(json['actualHours'].toString())
          : null,
      status: json['status'] ?? 'Completed',
    );
  }
}

class AdminAttendanceHistoryModel extends ShiftRecordModel {
  final int employeeId;
  final String employeeName;
  final String? employeeEmail;

  AdminAttendanceHistoryModel({
    required super.attendanceId,
    required super.shiftAssignmentId,
    required super.shiftName,
    required super.shiftDate,
    required super.checkInAt,
    super.checkOutAt,
    super.actualHours,
    required super.status,
    required this.employeeId,
    required this.employeeName,
    this.employeeEmail,
  });

  factory AdminAttendanceHistoryModel.fromJson(Map<String, dynamic> json) {
    final base = ShiftRecordModel.fromJson(json);
    return AdminAttendanceHistoryModel(
      attendanceId: base.attendanceId,
      shiftAssignmentId: base.shiftAssignmentId,
      shiftName: base.shiftName,
      shiftDate: base.shiftDate,
      checkInAt: base.checkInAt,
      checkOutAt: base.checkOutAt,
      actualHours: base.actualHours,
      status: base.status,
      employeeId: _parseNullableInt(json['employeeId']) ?? 0,
      employeeName: json['employeeName']?.toString() ?? '',
      employeeEmail: json['employeeEmail']?.toString(),
    );
  }
}

class AdminAttendanceHistoryPageModel {
  final List<AdminAttendanceHistoryModel> records;
  final int totalCount;
  final int page;
  final int pageSize;

  const AdminAttendanceHistoryPageModel({
    required this.records,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
}

class AttendanceService {
  /// 1. Xác thực mã QR và tra cứu các ca làm việc của nhân viên
  static Future<VerifyQrResult> verifyQr(String qrPayload) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return VerifyQrResult(
          isSuccess: false,
          storeCode: '',
          storeName: '',
          message: 'Vui lòng đăng nhập để thực hiện chấm công.',
          eligibleShifts: [],
          errorCode: 'unauthorized',
        );
      }

      final response = await AuthService.authenticatedRequest((token) => http
          .post(
            Uri.parse(ApiConfig.verifyQrUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'qrPayload': qrPayload.trim()}),
          )
          .timeout(const Duration(seconds: 10)));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}

      if (response.statusCode == 200) {
        final shiftsList = (data['eligibleShifts'] as List<dynamic>? ?? [])
            .map((e) => EligibleShiftModel.fromJson(e as Map<String, dynamic>))
            .toList();

        return VerifyQrResult(
          isSuccess: true,
          storeCode: data['storeCode'] ?? '',
          storeName: data['storeName'] ?? 'Chi Nhánh Cửa Hàng',
          message: data['message'] ?? 'Xác thực mã QR thành công!',
          eligibleShifts: shiftsList,
          recommendedAction: data['recommendedAction'],
        );
      } else {
        final code = data['code'] ?? 'invalid_qr';
        final title =
            data['title'] ??
            data['message'] ??
            'Mã QR không hợp lệ hoặc đã hết hạn.';
        return VerifyQrResult(
          isSuccess: false,
          storeCode: '',
          storeName: '',
          message: title.toString(),
          eligibleShifts: [],
          errorCode: code.toString(),
        );
      }
    } catch (_) {
      return VerifyQrResult(
        isSuccess: false,
        storeCode: '',
        storeName: '',
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.',
        eligibleShifts: [],
        errorCode: 'network_error',
      );
    }
  }

  /// 2. Gửi yêu cầu Check-in hoặc Check-out cho một ca cụ thể
  static Future<SubmitAttendanceResult> submitAttendance({
    required int? shiftAssignmentId,
    required String action,
    required String qrPayload,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SubmitAttendanceResult(
          isSuccess: false,
          message: 'Phiên đăng nhập hết hạn.',
          shiftAssignmentId: shiftAssignmentId,
          shiftName: '',
          action: action,
          timestamp: DateTime.now(),
          errorCode: 'unauthorized',
        );
      }

      final position = await AttendanceLocationService.getCurrentPosition();

      final response = await AuthService.authenticatedRequest((token) => http
          .post(
            Uri.parse(ApiConfig.submitAttendanceUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'shiftAssignmentId': shiftAssignmentId,
              'action': action,
              'qrPayload': qrPayload.trim(),
              'location': position.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 12)));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}

      if (response.statusCode == 200) {
        final ts = data['timestampUtc'] != null
            ? DateTime.tryParse(data['timestampUtc'].toString())?.toLocal() ??
                  DateTime.now()
            : DateTime.now();

        final hours = data['actualHours'] != null
            ? double.tryParse(data['actualHours'].toString())
            : null;
        final location = data['location'] is Map<String, dynamic>
            ? AttendanceProofModel.fromJson(
                data['location'] as Map<String, dynamic>,
              )
            : null;

        return SubmitAttendanceResult(
          isSuccess: true,
          message: data['message'] ?? 'Thao tác chấm công thành công!',
          shiftAssignmentId: shiftAssignmentId,
          shiftName: data['shiftName'] ?? 'Ca làm việc',
          action: data['action'] ?? action,
          timestamp: ts,
          actualHours: hours,
          location: location,
        );
      } else {
        final code = data['code'] ?? 'submit_error';
        final title =
            data['title'] ??
            data['message'] ??
            'Chấm công không thành công. Vui lòng thử lại.';
        return SubmitAttendanceResult(
          isSuccess: false,
          message: title.toString(),
          shiftAssignmentId: shiftAssignmentId,
          shiftName: '',
          action: action,
          timestamp: DateTime.now(),
          errorCode: code.toString(),
        );
      }
    } on AttendanceLocationException catch (e) {
      return SubmitAttendanceResult(
        isSuccess: false,
        message: e.message,
        shiftAssignmentId: shiftAssignmentId,
        shiftName: '',
        action: action,
        timestamp: DateTime.now(),
        errorCode: e.code,
      );
    } catch (_) {
      return SubmitAttendanceResult(
        isSuccess: false,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.',
        shiftAssignmentId: shiftAssignmentId,
        shiftName: '',
        action: action,
        timestamp: DateTime.now(),
        errorCode: 'network_error',
      );
    }
  }

  /// 3. Lấy lịch sử chấm công theo ca của nhân viên
  static Future<List<ShiftRecordModel>> getShiftHistory({
    int limit = 20,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await AuthService.authenticatedRequest((token) => http
          .get(
            Uri.parse('${ApiConfig.shiftHistoryUrl}?limit=$limit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final list =
            jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>? ?? [];
        return list
            .map((e) => ShiftRecordModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<ShiftRecordModel>> getMyAttendanceHistory({
    int limit = 100,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Phiên đăng nhập đã hết hạn.');
    final response = await AuthService.authenticatedRequest((token) => http
        .get(
          Uri.parse('${ApiConfig.shiftHistoryUrl}?limit=$limit'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15)));
    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final message = data is Map
          ? data['title']?.toString() ?? 'Không tải được lịch sử chấm công.'
          : 'Không tải được lịch sử chấm công.';
      throw Exception(message);
    }
    if (data is! List) {
      throw const FormatException('Dữ liệu lịch sử không hợp lệ.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ShiftRecordModel.fromJson)
        .toList();
  }

  static Future<AdminAttendanceHistoryPageModel> getAdminAttendanceHistory({
    required DateTime fromDate,
    required DateTime toDate,
    int page = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse(ApiConfig.adminAttendanceHistoryUrl).replace(
      queryParameters: {
        'fromDate': _formatDate(fromDate),
        'toDate': _formatDate(toDate),
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Phiên đăng nhập đã hết hạn.');

    final response = await AuthService.authenticatedRequest((token) => http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15)));
    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final message = data is Map
          ? data['title']?.toString() ?? 'Không tải được lịch sử chấm công.'
          : 'Không tải được lịch sử chấm công.';
      throw Exception(message);
    }
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu lịch sử không hợp lệ.');
    }
    final records = data['records'];
    if (records is! List) {
      throw const FormatException('Danh sách chấm công không hợp lệ.');
    }
    return AdminAttendanceHistoryPageModel(
      records: records
          .whereType<Map<String, dynamic>>()
          .map(AdminAttendanceHistoryModel.fromJson)
          .toList(),
      totalCount: _parseNullableInt(data['totalCount']) ?? 0,
      page: _parseNullableInt(data['page']) ?? page,
      pageSize: _parseNullableInt(data['pageSize']) ?? pageSize,
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int? _parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
