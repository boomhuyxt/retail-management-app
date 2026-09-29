import 'package:flutter/foundation.dart';

class ApiConfig {
  // Cấu hình URL mặc định:
  // - Máy thật cắm cáp USB (kèm lệnh adb reverse tcp:8080 tcp:8080): http://127.0.0.1:8080
  // - Máy thật dùng Wi-Fi chung mạng: http://192.168.2.248:8080
  // - Android Emulator: http://10.0.2.2:8080
  // - Web / Windows Desktop: http://localhost:8080
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // Sử dụng trực tiếp IP máy tính trong mạng Wi-Fi (192.168.2.248) để điện thoại kết nối không bị phụ thuộc cáp USB
    return 'http://192.168.2.248:8080';
  }

  static String baseUrl = defaultBaseUrl;

  // Endpoints
  static String get loginUrl => '$baseUrl/api/auth/login';
  static String get registerUrl => '$baseUrl/api/auth/register';
  static String get meUrl => '$baseUrl/api/auth/me';
  static String get forgotPasswordUrl => '$baseUrl/api/auth/forgot-password';
  static String get verifyResetCodeUrl => '$baseUrl/api/auth/verify-reset-code';
  static String get resetPasswordUrl => '$baseUrl/api/auth/reset-password';

  static String get checkInUrl => '$baseUrl/api/attendance-check-ins';
  static String get attendanceRecordsMeUrl =>
      '$baseUrl/api/attendance-records/me';
  static String get attendanceSessionsUrl => '$baseUrl/api/attendance-sessions';

  // Shift Attendance Endpoints
  static String get kioskQrUrl => '$baseUrl/api/attendance-qr/kiosk';
  static String get verifyQrUrl => '$baseUrl/api/attendance/verify-qr';
  static String get submitAttendanceUrl => '$baseUrl/api/attendance/submit';
  static String get shiftHistoryUrl => '$baseUrl/api/attendance/history';
}
