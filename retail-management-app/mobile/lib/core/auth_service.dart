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
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      role: json['role'] ?? 'Employee',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'role': role,
    };
  }
}

class AuthResult {
  final bool isSuccess;
  final String message;
  final UserModel? user;
  final String? token;

  AuthResult({
    required this.isSuccess,
    required this.message,
    this.user,
    this.token,
  });
}

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';

  static UserModel? currentUser;
  static String? currentToken;

  /// Đăng nhập nhân viên
  static Future<AuthResult> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        final token = data['accessToken'] as String;
        final user = UserModel.fromJson(data['user']);

        await saveSession(token, user);
        return AuthResult(
          isSuccess: true,
          message: 'Đăng nhập thành công',
          user: user,
          token: token,
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
        final title = data['title'] ?? data['message'] ?? 'Đăng nhập thất bại (${response.statusCode})';
        return AuthResult(isSuccess: false, message: title.toString());
      }
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Không thể kết nối đến máy chủ: $e',
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
      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'displayName': displayName.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        final token = data['accessToken'] as String;
        final user = UserModel.fromJson(data['user']);

        await saveSession(token, user);
        return AuthResult(
          isSuccess: true,
          message: 'Đăng ký thành công',
          user: user,
          token: token,
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
        final title = data['title'] ?? data['message'] ?? 'Đăng ký không thành công';
        return AuthResult(isSuccess: false, message: title.toString());
      }
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Lỗi kết nối máy chủ: $e',
      );
    }
  }

  /// Lưu Token và Thông tin User vào local storage
  static Future<void> saveSession(String token, UserModel user) async {
    currentToken = token;
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  /// Khôi phục phiên đăng nhập trước đó
  static Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final userStr = prefs.getString(_keyUser);

      if (token != null && userStr != null) {
        currentToken = token;
        currentUser = UserModel.fromJson(jsonDecode(userStr));
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Lấy Bearer Token hiện tại
  static Future<String?> getToken() async {
    if (currentToken != null) return currentToken;
    final prefs = await SharedPreferences.getInstance();
    currentToken = prefs.getString(_keyToken);
    return currentToken;
  }

  /// Đăng xuất
  static Future<void> logout() async {
    currentToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }
}
