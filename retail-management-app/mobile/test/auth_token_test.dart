import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.logout();
  });

  group('AuthService Token & Session Management Tests (FB/Youtube Sliding Pattern)', () {
    final testUser = UserModel(
      id: 10,
      email: 'nhanvien@retail365.com',
      displayName: 'Nguyen Van B',
      role: 'Employee',
    );

    test('saveSession correctly stores access token, refresh token, and user info', () async {
      final now = DateTime.now();
      final accessExpiresAt = now.add(const Duration(hours: 1));
      final refreshExpiresAt = now.add(const Duration(days: 30));

      await AuthService.saveSession(
        token: 'access_jwt_token_sample',
        user: testUser,
        refreshToken: 'refresh_token_sample_string',
        expiresAt: accessExpiresAt,
        refreshExpiresAt: refreshExpiresAt,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'access_jwt_token_sample');
      expect(prefs.getString('auth_refresh_token'), 'refresh_token_sample_string');
      expect(prefs.getString('auth_token_expires_at'), accessExpiresAt.toIso8601String());
      expect(prefs.getString('auth_refresh_token_expires_at'), refreshExpiresAt.toIso8601String());

      final storedUserJson = jsonDecode(prefs.getString('auth_user')!);
      expect(storedUserJson['email'], 'nhanvien@retail365.com');
      expect(AuthService.currentToken, 'access_jwt_token_sample');
      expect(AuthService.currentRefreshToken, 'refresh_token_sample_string');
      expect(AuthService.currentUser?.displayName, 'Nguyen Van B');
    });

    test('isAccessTokenValid accurately determines token expiration status', () async {
      AuthService.currentToken = 'dummy_token';

      // Token expires in 10 minutes -> Still valid
      AuthService.tokenExpiresAt = DateTime.now().add(const Duration(minutes: 10));
      expect(AuthService.isAccessTokenValid(), isTrue);

      // Token expires in 1 minute -> Within 2-min buffer, considered expiring/invalid for safety
      AuthService.tokenExpiresAt = DateTime.now().add(const Duration(minutes: 1));
      expect(AuthService.isAccessTokenValid(), isFalse);

      // Token expired 5 minutes ago -> Expired
      AuthService.tokenExpiresAt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(AuthService.isAccessTokenValid(), isFalse);
    });

    test('restoreSession maintains valid session seamlessly', () async {
      final accessExpiresAt = DateTime.now().add(const Duration(hours: 1));
      final refreshExpiresAt = DateTime.now().add(const Duration(days: 30));

      await AuthService.saveSession(
        token: 'active_token',
        user: testUser,
        refreshToken: 'active_refresh_token',
        expiresAt: accessExpiresAt,
        refreshExpiresAt: refreshExpiresAt,
      );

      // Clear memory variables to simulate app freshly starting
      AuthService.currentToken = null;
      AuthService.currentRefreshToken = null;
      AuthService.currentUser = null;

      final restored = await AuthService.restoreSession();
      expect(restored, isTrue);
      expect(AuthService.currentToken, 'active_token');
      expect(AuthService.currentRefreshToken, 'active_refresh_token');
      expect(AuthService.currentUser?.id, 10);
    });

    test('restoreSession automatically logs out when refresh token has expired (30 days of inactivity)', () async {
      // Simulate user has not opened the app for 35 days
      final expiredRefresh = DateTime.now().subtract(const Duration(days: 5));
      final expiredAccess = DateTime.now().subtract(const Duration(days: 35));

      await AuthService.saveSession(
        token: 'old_expired_access_token',
        user: testUser,
        refreshToken: 'old_expired_refresh_token',
        expiresAt: expiredAccess,
        refreshExpiresAt: expiredRefresh,
      );

      // Clear memory
      AuthService.currentToken = null;
      AuthService.currentRefreshToken = null;
      AuthService.currentUser = null;

      final restored = await AuthService.restoreSession();
      expect(restored, isFalse);
      expect(AuthService.currentToken, isNull);
      expect(AuthService.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
    });

    test('logout cleanly clears all local storage and memory state', () async {
      await AuthService.saveSession(
        token: 'token_to_clear',
        user: testUser,
        refreshToken: 'refresh_to_clear',
      );

      await AuthService.logout();

      expect(AuthService.currentToken, isNull);
      expect(AuthService.currentRefreshToken, isNull);
      expect(AuthService.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(prefs.getString('auth_user'), isNull);
    });
  });
}
