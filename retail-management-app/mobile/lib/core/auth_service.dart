import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class UserModel {
  final int id;
  final String email;
  final String displayName;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      role: json['role'] ?? 'Employee',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'displayName': displayName, 'role': role};
  }
}

class AuthResult {
  final bool isSuccess;
  final String message;
  final UserModel? user;
  final String? token;
  final String? refreshToken;

  AuthResult({
    required this.isSuccess,
    required this.message,
    this.user,
    this.token,
    this.refreshToken,
  });
}

class PasswordResetResult {
  final bool isSuccess;
  final String message;
  final String? resetToken;

  const PasswordResetResult({
    required this.isSuccess,
    required this.message,
    this.resetToken,
  });
}

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUser = 'auth_user';
  static const String _keyTokenExpiresAt = 'auth_token_expires_at';
  static const String _keyRefreshTokenExpiresAt = 'auth_refresh_token_expires_at';

  static UserModel? currentUser;
  static String? currentToken;
  static String? currentRefreshToken;
  static DateTime? tokenExpiresAt;
  static DateTime? refreshTokenExpiresAt;

  /// Callback khi phiên đăng nhập hết hạn hoàn toàn (sau 30 ngày không dùng hoặc bị revoke)
  static void Function()? onSessionExpired;

  /// Đăng nhập nhân viên
  static Future<AuthResult> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        final token = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String?;
        final expiresAtStr = data['expiresAtUtc'] as String?;
        final refreshExpiresAtStr = data['refreshTokenExpiresAtUtc'] as String?;
        final user = UserModel.fromJson(data['user']);

        await saveSession(
          token: token,
          user: user,
          refreshToken: refreshToken,
          expiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
          refreshExpiresAt: refreshExpiresAtStr != null ? DateTime.tryParse(refreshExpiresAtStr) : null,
        );

        return AuthResult(
          isSuccess: true,
          message: 'Đăng nhập thành công',
          user: user,
          token: token,
          refreshToken: refreshToken,
        );
      } else if (response.statusCode == 401) {
        return AuthResult(
          isSuccess: false,
          message: 'Email hoặc mật khẩu không chính xác.',
        );
      } else if (response.statusCode == 429) {
        return AuthResult(
          isSuccess: false,
          message: 'Quá nhiều lần thử đăng nhập. Vui lòng thử lại sau 1 phút.',
        );
      } else {
        final title =
            data['title'] ??
            data['message'] ??
            'Đăng nhập không thành công. Vui lòng kiểm tra lại thông tin.';
        return AuthResult(isSuccess: false, message: title.toString());
      }
    } catch (_) {
      return AuthResult(
        isSuccess: false,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.',
      );
    }
  }

  /// Đăng ký tài khoản nhân viên
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.registerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'displayName': displayName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        final token = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String?;
        final expiresAtStr = data['expiresAtUtc'] as String?;
        final refreshExpiresAtStr = data['refreshTokenExpiresAtUtc'] as String?;
        final user = UserModel.fromJson(data['user']);

        await saveSession(
          token: token,
          user: user,
          refreshToken: refreshToken,
          expiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
          refreshExpiresAt: refreshExpiresAtStr != null ? DateTime.tryParse(refreshExpiresAtStr) : null,
        );

        return AuthResult(
          isSuccess: true,
          message: 'Đăng ký thành công',
          user: user,
          token: token,
          refreshToken: refreshToken,
        );
      } else if (response.statusCode == 409) {
        return AuthResult(
          isSuccess: false,
          message: 'Email này đã được đăng ký trong hệ thống.',
        );
      } else {
        if (data is Map && data['errors'] is Map) {
          final errorsMap = data['errors'] as Map;
          final errorList = <String>[];
          errorsMap.forEach((key, value) {
            if (value is List) {
              for (final v in value) {
                errorList.add(v.toString());
              }
            } else {
              errorList.add(value.toString());
            }
          });
          if (errorList.isNotEmpty) {
            return AuthResult(isSuccess: false, message: errorList.join('\n'));
          }
        }
        final title =
            data['title'] ?? data['message'] ?? 'Đăng ký không thành công';
        return AuthResult(isSuccess: false, message: title.toString());
      }
    } catch (_) {
      return AuthResult(
        isSuccess: false,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.',
      );
    }
  }

  static Future<PasswordResetResult> requestPasswordReset(String email) async {
    return _postPasswordReset(
      ApiConfig.forgotPasswordUrl,
      {'email': email.trim()},
      successMessage: 'Nếu email tồn tại, mã xác nhận đã được gửi.',
    );
  }

  static Future<PasswordResetResult> verifyResetCode({
    required String email,
    required String code,
  }) async {
    return _postPasswordReset(
      ApiConfig.verifyResetCodeUrl,
      {'email': email.trim(), 'code': code.trim()},
      successMessage: 'Mã xác nhận hợp lệ.',
      includeResetToken: true,
    );
  }

  static Future<PasswordResetResult> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    return _postPasswordReset(ApiConfig.resetPasswordUrl, {
      'email': email.trim(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    }, successMessage: 'Mật khẩu đã được cập nhật.');
  }

  static Future<PasswordResetResult> _postPasswordReset(
    String url,
    Map<String, String> body, {
    required String successMessage,
    bool includeResetToken = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final dynamic data = response.bodyBytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PasswordResetResult(
          isSuccess: true,
          message: data is Map
              ? data['message']?.toString() ?? successMessage
              : successMessage,
          resetToken: includeResetToken && data is Map
              ? data['resetToken']?.toString()
              : null,
        );
      }

      final fallback = response.statusCode == 429
          ? 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.'
          : 'Yêu cầu không hợp lệ hoặc đã hết hạn.';
      return PasswordResetResult(
        isSuccess: false,
        message: data is Map ? data['title']?.toString() ?? fallback : fallback,
      );
    } catch (_) {
      return const PasswordResetResult(
        isSuccess: false,
        message:
            'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
  }

  /// Kiểm tra Access Token hiện tại còn hạn không (dự phòng đệm 2 phút)
  static bool isAccessTokenValid() {
    if (currentToken == null || currentToken!.isEmpty) return false;
    if (tokenExpiresAt == null) return true;
    return tokenExpiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 2)));
  }

  /// Làm mới phiên đăng nhập (Sliding Expiration / Refresh Token - mô hình FB & Youtube)
  static Future<bool> refreshSession() async {
    var refreshToken = currentRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      refreshToken = prefs.getString(_keyRefreshToken);
      currentRefreshToken = refreshToken;
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.refreshTokenUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final newToken = data['accessToken'] as String;
        final newRefreshToken = (data['refreshToken'] as String?) ?? refreshToken;
        final expiresAtStr = data['expiresAtUtc'] as String?;
        final refreshExpiresAtStr = data['refreshTokenExpiresAtUtc'] as String?;
        final user = data['user'] != null
            ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
            : currentUser;

        if (user != null) {
          await saveSession(
            token: newToken,
            user: user,
            refreshToken: newRefreshToken,
            expiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
            refreshExpiresAt: refreshExpiresAtStr != null ? DateTime.tryParse(refreshExpiresAtStr) : null,
          );
          return true;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Refresh token đã hết hạn (quá 30 ngày không truy cập) hoặc bị hủy -> Đăng xuất
        await logout();
        return false;
      }
    } catch (_) {
      // Lỗi mạng tạm thời -> Không logout để không ngắt trải nghiệm ngoại tuyến
    }
    return false;
  }

  /// Lưu Token, Refresh Token và Thông tin User vào local storage
  static Future<void> saveSession({
    required String token,
    required UserModel user,
    String? refreshToken,
    DateTime? expiresAt,
    DateTime? refreshExpiresAt,
  }) async {
    currentToken = token;
    currentUser = user;
    if (refreshToken != null) currentRefreshToken = refreshToken;
    tokenExpiresAt = expiresAt;
    refreshTokenExpiresAt = refreshExpiresAt;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    if (refreshToken != null) {
      await prefs.setString(_keyRefreshToken, refreshToken);
    }
    if (expiresAt != null) {
      await prefs.setString(_keyTokenExpiresAt, expiresAt.toIso8601String());
    }
    if (refreshExpiresAt != null) {
      await prefs.setString(_keyRefreshTokenExpiresAt, refreshExpiresAt.toIso8601String());
    }
  }

  /// Khôi phục phiên đăng nhập khi mở app
  static Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final refreshToken = prefs.getString(_keyRefreshToken);
      final userStr = prefs.getString(_keyUser);
      final expiresAtStr = prefs.getString(_keyTokenExpiresAt);
      final refreshExpiresAtStr = prefs.getString(_keyRefreshTokenExpiresAt);

      if (token == null && refreshToken == null) return false;
      if (userStr == null) return false;

      currentToken = token;
      currentRefreshToken = refreshToken;
      currentUser = UserModel.fromJson(jsonDecode(userStr));
      if (expiresAtStr != null) tokenExpiresAt = DateTime.tryParse(expiresAtStr);
      if (refreshExpiresAtStr != null) {
        refreshTokenExpiresAt = DateTime.tryParse(refreshExpiresAtStr);
      }

      // Kiểm tra nếu refresh token đã quá hạn tuyệt đối theo đồng hồ máy
      if (refreshTokenExpiresAt != null &&
          DateTime.now().isAfter(refreshTokenExpiresAt!)) {
        await logout();
        return false;
      }

      // Nếu token còn hạn -> Duy trì đăng nhập ngay lập tức
      if (isAccessTokenValid()) {
        return true;
      }

      // Nếu token hết hạn (ví dụ mở app sau 1 đêm): tự động âm thầm làm mới token
      if (currentRefreshToken != null) {
        final refreshed = await refreshSession();
        if (refreshed) {
          return true;
        }

        // Nếu máy chủ đã từ chối refresh token (401), session đã bị logout
        if (currentToken == null && currentRefreshToken == null) {
          return false;
        }
      }

      // Nếu ngoại tuyến hoặc mạng chập chờn, vẫn duy trì phiên người dùng
      return currentUser != null;
    } catch (_) {}
    return false;
  }

  /// Lấy Bearer Token hợp lệ, tự động refresh nếu sắp hoặc đã hết hạn
  static Future<String?> getValidToken() async {
    if (isAccessTokenValid()) {
      return currentToken;
    }

    final refreshed = await refreshSession();
    if (refreshed && currentToken != null) {
      return currentToken;
    }

    if (currentToken != null) return currentToken;
    final prefs = await SharedPreferences.getInstance();
    currentToken = prefs.getString(_keyToken);
    return currentToken;
  }

  /// Lấy Bearer Token hiện tại
  static Future<String?> getToken() async {
    return getValidToken();
  }

  /// Bộ thực thi request HTTP có xác thực: Tự động đính kèm token & Tự động thử lại nếu gặp 401
  static Future<http.Response> authenticatedRequest(
    Future<http.Response> Function(String token) requestFn,
  ) async {
    var token = await getValidToken();
    if (token == null) {
      return http.Response(
        jsonEncode({'title': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'}),
        401,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    var response = await requestFn(token);

    // Nếu máy chủ trả về 401: Tự động âm thầm refresh token và thực hiện lại request 1 lần nữa
    if (response.statusCode == 401) {
      final refreshed = await refreshSession();
      if (refreshed && currentToken != null) {
        response = await requestFn(currentToken!);
      } else {
        await logout();
        onSessionExpired?.call();
      }
    }

    return response;
  }

  /// Đăng xuất: Xóa phiên cục bộ và báo máy chủ thu hồi refresh token
  static Future<void> logout() async {
    final tokenToRevoke = currentRefreshToken;
    currentToken = null;
    currentRefreshToken = null;
    currentUser = null;
    tokenExpiresAt = null;
    refreshTokenExpiresAt = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyTokenExpiresAt);
    await prefs.remove(_keyRefreshTokenExpiresAt);

    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      try {
        http.post(
          Uri.parse(ApiConfig.revokeTokenUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': tokenToRevoke}),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }
}
