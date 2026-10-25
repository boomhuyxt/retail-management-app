import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class LeaveRequestItem {
  final int id;
  final int version;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String unit;
  final String reasonCode;
  final String reason;
  final bool isEmergency;
  final bool isLateSubmission;
  final String? lateSubmissionReason;
  final int? shiftAssignmentId;
  final String? date;
  final String? startDate;
  final String? endDate;
  final int? calendarDays;
  final int scheduledLeaveMinutes;
  final String scheduleBasis;
  final String status;
  final String payrollTreatment;
  final String payrollReadiness;
  final DateTime createdAtUtc;
  final String? reviewNote;
  final String? rejectionReason;
  final String? revocationReason;
  final String requestedPeriod;

  const LeaveRequestItem({
    required this.id,
    required this.version,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.unit,
    required this.reasonCode,
    required this.reason,
    required this.isEmergency,
    required this.isLateSubmission,
    this.lateSubmissionReason,
    this.shiftAssignmentId,
    this.date,
    this.startDate,
    this.endDate,
    this.calendarDays,
    required this.scheduledLeaveMinutes,
    required this.scheduleBasis,
    required this.status,
    required this.payrollTreatment,
    required this.payrollReadiness,
    required this.createdAtUtc,
    this.reviewNote,
    this.rejectionReason,
    this.revocationReason,
    required this.requestedPeriod,
  });

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    return LeaveRequestItem(
      id: (json['id'] as num).toInt(),
      version: (json['version'] as num? ?? 1).toInt(),
      employeeId: (json['employeeId'] as num).toInt(),
      employeeName: (json['employeeName'] as String?) ?? '',
      employeeCode: (json['employeeCode'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? 'Day',
      reasonCode: (json['reasonCode'] as String?) ?? 'Personal',
      reason: (json['reason'] as String?) ?? '',
      isEmergency: json['isEmergency'] == true,
      isLateSubmission: json['isLateSubmission'] == true,
      lateSubmissionReason: json['lateSubmissionReason'] as String?,
      shiftAssignmentId: (json['shiftAssignmentId'] as num?)?.toInt(),
      date: json['date'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      calendarDays: (json['calendarDays'] as num?)?.toInt(),
      scheduledLeaveMinutes: (json['scheduledLeaveMinutes'] as num? ?? 0)
          .toInt(),
      scheduleBasis: (json['scheduleBasis'] as String?) ?? 'Available',
      status: (json['status'] as String?) ?? 'Pending',
      payrollTreatment: (json['payrollTreatment'] as String?) ?? 'Unresolved',
      payrollReadiness: (json['payrollReadiness'] as String?) ?? 'NeedsReview',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '') ??
          DateTime.now(),
      reviewNote: json['reviewNote'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      revocationReason: json['revocationReason'] as String?,
      requestedPeriod: (json['requestedPeriod'] as String?) ?? '',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'Pending':
        return 'Chờ duyệt';
      case 'Approved':
        return 'Đã duyệt';
      case 'Rejected':
        return 'Từ chối';
      case 'Cancelled':
        return 'Đã hủy';
      case 'Revoked':
        return 'Đã thu hồi';
      default:
        return status;
    }
  }

  String get reasonLabel {
    switch (reasonCode) {
      case 'Personal':
        return 'Việc cá nhân';
      case 'FamilyEmergency':
        return 'Việc gia đình đột xuất';
      case 'Sickness':
        return 'Ốm đau / Khám bệnh';
      case 'Maternity':
        return 'Thai sản';
      case 'Other':
        return 'Lý do khác';
      default:
        return reasonCode;
    }
  }
}

class LeavePreviewModel {
  final String previewToken;
  final String requestedPeriod;
  final int scheduledLeaveMinutes;
  final int? calendarDays;
  final String scheduleBasis;
  final bool isLateSubmission;
  final bool isLongLeave;
  final bool hasExpandedCoverage;
  final List<String> warnings;
  final bool hasConflict;
  final String? conflictReason;
  final List<Map<String, dynamic>> effectiveIntervals;
  final List<Map<String, dynamic>> affectedAssignments;

  const LeavePreviewModel({
    required this.previewToken,
    required this.requestedPeriod,
    required this.scheduledLeaveMinutes,
    this.calendarDays,
    required this.scheduleBasis,
    required this.isLateSubmission,
    required this.isLongLeave,
    required this.hasExpandedCoverage,
    required this.warnings,
    required this.hasConflict,
    this.conflictReason,
    this.effectiveIntervals = const [],
    this.affectedAssignments = const [],
  });

  factory LeavePreviewModel.fromJson(Map<String, dynamic> json) {
    return LeavePreviewModel(
      previewToken: json['previewToken'] as String? ?? '',
      requestedPeriod: json['requestedPeriod'] as String? ?? '',
      scheduledLeaveMinutes: (json['scheduledLeaveMinutes'] as num? ?? 0)
          .toInt(),
      calendarDays: (json['calendarDays'] as num?)?.toInt(),
      scheduleBasis: json['scheduleBasis'] as String? ?? 'Available',
      isLateSubmission: json['isLateSubmission'] == true,
      isLongLeave: json['isLongLeave'] == true,
      hasExpandedCoverage: json['hasExpandedCoverage'] == true,
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hasConflict: json['hasConflict'] == true,
      conflictReason: json['conflictReason'] as String?,
      effectiveIntervals: (json['effectiveIntervals'] as List? ?? [])
          .cast<Map<String, dynamic>>(),
      affectedAssignments: (json['affectedAssignments'] as List? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }
}

class LeaveRequestService {
  static Future<Map<String, dynamic>> getDetail(int id) async {
    final response = await AuthService.authenticatedRequest(
      (token) => http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/leave-requests/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode != 200)
      throw Exception(_parseErrorMessage(response));
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<LeaveRequestItem>> getMyLeaveRequests({
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = {'page': '$page', 'pageSize': '$pageSize'};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/leave-requests/me',
    ).replace(queryParameters: queryParams);

    final response = await AuthService.authenticatedRequest(
      (token) => http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15)),
    );

    if (response.statusCode != 200) {
      final msg = _parseErrorMessage(response);
      throw Exception(msg);
    }

    final map =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = (map['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => LeaveRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<LeavePreviewModel> preview(Map<String, dynamic> input) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/leave-requests/preview');
    final response = await AuthService.authenticatedRequest(
      (token) => http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(input),
          )
          .timeout(const Duration(seconds: 15)),
    );

    if (response.statusCode != 200) {
      final msg = _parseErrorMessage(response);
      throw Exception(msg);
    }

    final map =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LeavePreviewModel.fromJson(map);
  }

  static Future<LeaveRequestItem> create(
    Map<String, dynamic> command, {
    String? idempotencyKey,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/leave-requests');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    final response = await AuthService.authenticatedRequest((token) {
      headers['Authorization'] = 'Bearer $token';
      return http
          .post(uri, headers: headers, body: jsonEncode(command))
          .timeout(const Duration(seconds: 15));
    });

    if (response.statusCode != 201 && response.statusCode != 200) {
      final msg = _parseErrorMessage(response);
      throw Exception(msg);
    }

    final map =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LeaveRequestItem.fromJson(map);
  }

  static Future<LeaveRequestItem> cancel(
    int id,
    int version, {
    String? note,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/leave-requests/$id/cancel');
    final response = await AuthService.authenticatedRequest(
      (token) => http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'version': version, 'note': note}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    if (response.statusCode != 200) {
      final msg = _parseErrorMessage(response);
      throw Exception(msg);
    }

    final map =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return LeaveRequestItem.fromJson(map);
  }

  static String _parseErrorMessage(http.Response response) {
    try {
      final map =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (map['detail'] ??
              map['title'] ??
              'Lỗi máy chủ (${response.statusCode})')
          as String;
    } catch (_) {
      return 'Lỗi kết nối máy chủ (${response.statusCode})';
    }
  }
}
