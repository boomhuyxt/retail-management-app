import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiConfig.baseUrl = ApiConfig.defaultBaseUrl;
  });

  test('uses the deployed API by default', () {
    expect(ApiConfig.defaultBaseUrl, 'https://www.manage365.io.vn');
    expect(ApiConfig.loginUrl, 'https://www.manage365.io.vn/api/auth/login');
  });

  test('normalizes a copied Swagger URL', () {
    ApiConfig.baseUrl = 'https://www.manage365.io.vn/swagger/index.html/';

    expect(ApiConfig.baseUrl, 'https://www.manage365.io.vn');
    expect(
      ApiConfig.verifyQrUrl,
      'https://www.manage365.io.vn/api/attendance/verify-qr',
    );
  });

  test('removes a trailing slash from the API base URL', () {
    ApiConfig.baseUrl = 'https://api.example.com/';

    expect(ApiConfig.baseUrl, 'https://api.example.com');
    expect(ApiConfig.registerUrl, 'https://api.example.com/api/auth/register');
  });

  test('prepends http:// when scheme is missing', () {
    ApiConfig.baseUrl = '192.168.2.248:5000';

    expect(ApiConfig.baseUrl, 'http://192.168.2.248:5000');
    expect(ApiConfig.loginUrl, 'http://192.168.2.248:5000/api/auth/login');
  });
}
