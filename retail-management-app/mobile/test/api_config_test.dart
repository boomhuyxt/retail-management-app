import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_config.dart';

void main() {
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
}
