class ApiConfig {
  static const String deployedBaseUrl = 'https://www.manage365.io.vn';

  /// Có thể ghi đè khi build bằng:
  /// `flutter build apk --dart-define=API_BASE_URL=https://example.com`
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: deployedBaseUrl,
  );

  static String get defaultBaseUrl => _normalizeBaseUrl(_configuredBaseUrl);

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static set baseUrl(String value) {
    _baseUrl = _normalizeBaseUrl(value);
  }

  /// Chấp nhận domain gốc, URL Swagger và URL có dấu gạch chéo cuối.
  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    const swaggerSuffixes = ['/swagger/index.html', '/swagger/v1/swagger.json'];

    for (final suffix in swaggerSuffixes) {
      if (normalized.toLowerCase().endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }

    return normalized.replaceFirst(RegExp(r'/+$'), '');
  }

  static String get loginUrl => '$baseUrl/api/auth/login';
  static String get registerUrl => '$baseUrl/api/auth/register';
  static String get refreshTokenUrl => '$baseUrl/api/auth/refresh';
  static String get revokeTokenUrl => '$baseUrl/api/auth/revoke';
  static String get meUrl => '$baseUrl/api/auth/me';
  static String get forgotPasswordUrl => '$baseUrl/api/auth/forgot-password';
  static String get verifyResetCodeUrl => '$baseUrl/api/auth/verify-reset-code';
  static String get resetPasswordUrl => '$baseUrl/api/auth/reset-password';

  static String get checkInUrl => '$baseUrl/api/attendance-check-ins';
  static String get attendanceRecordsMeUrl =>
      '$baseUrl/api/attendance-records/me';
  static String get attendanceSessionsUrl => '$baseUrl/api/attendance-sessions';

  static String get kioskQrUrl => '$baseUrl/api/attendance-qr/kiosk';
  static String get verifyQrUrl => '$baseUrl/api/attendance/verify-qr';
  static String get submitAttendanceUrl => '$baseUrl/api/attendance/submit';
  static String get shiftHistoryUrl => '$baseUrl/api/attendance/history';
}
