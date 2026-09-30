# Retail Management Mobile App (Flutter)

Ứng dụng di động dành cho nhân viên cửa hàng thuộc hệ thống **Retail365 (Manage365)**, tích hợp chấm công đa tầng (Dynamic QR Code + GPS Geofencing), quản lý ca làm và lịch sử chấm công.

> 📖 **Xem tài liệu chi tiết và toàn diện tại:** [Root README.md](../../README.md) và [BAO_CAO_HE_THONG_BACKEND_VA_MOBILE_APP.md](../../BAO_CAO_HE_THONG_BACKEND_VA_MOBILE_APP.md).

---

## ⚡ Hướng Dẫn Nhanh (Quick Start)

### 1. Cài đặt thư viện
```bash
flutter pub get
```

### 2. Chạy Unit Tests
```bash
flutter test
```

### 3. Chạy Ứng dụng

Mặc định ứng dụng kết nối tới Backend Production: `https://www.manage365.io.vn`

```bash
# Chạy với cấu hình mặc định
flutter run

# Hoặc truyền URL Backend tùy chỉnh
flutter run --dart-define=API_BASE_URL=https://www.manage365.io.vn

# Chạy trên trình duyệt Chrome (Web test)
flutter run -d chrome
```

### 4. Build Bản Cài Đặt (Release APK)
```bash
flutter build apk --release
```
File APK thành phẩm nằm tại: `build/app/outputs/flutter-apk/app-release.apk`.
