import 'package:flutter/material.dart';
import 'admin_leave_management_screen.dart';
import 'core/api_config.dart';
import 'core/auth_service.dart';
import 'employee_leave_screen.dart';
import 'profile_detail_screen.dart'; // Import màn hình Chi tiết thông tin cá nhân
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _user;

  bool get _isAdminOrOwner {
    final role = (_user?.role ?? '').toLowerCase();
    return role.contains('admin') || role.contains('owner') || role.contains('chủ cửa hàng');
  }

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.displayName.isNotEmpty == true ? _user!.displayName : 'Quỳnh';
    final email = _user?.email.isNotEmpty == true ? _user!.email : 'balldinhnguyen140905@gmail.com';
    final role = _user?.role.isNotEmpty == true ? _user!.role : 'Employee';

    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: Thẻ thông tin nhân viên
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primaryOrange,
                      child: Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role == 'Employee' ? 'Nhân viên bán hàng' : role,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // DANH MỤC THÔNG TIN & CÀI ĐẶT
              const Text(
                'Tài khoản & Cài đặt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),

              // 1. Thông tin cá nhân (Đã kết nối điều hướng)
              _buildMenuTile(
                Icons.badge_outlined,
                'Thông tin cá nhân',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileDetailScreen()),
                  );
                },
              ),

              // 2. Các mục cài đặt khác
              _buildMenuTile(Icons.history, 'Lịch sử chấm công', () {}),
              _buildMenuTile(
                _isAdminOrOwner ? Icons.admin_panel_settings_outlined : Icons.event_note_outlined,
                _isAdminOrOwner ? 'Quản lý lịch sử nghỉ phép' : 'Đơn xin nghỉ phép',
                    () {
                  if (_isAdminOrOwner) {
                    // Điều hướng sang trang Quản lý nghỉ phép của Admin
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminLeaveManagementScreen()),
                    );
                  } else {
                    // Điều hướng sang trang Đơn xin nghỉ phép của Nhân viên
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EmployeeLeaveScreen()),
                    );
                  }
                },
              ),
              _buildMenuTile(Icons.dns_outlined, 'Cấu hình máy chủ API', _showServerConfigDialog),

              _buildMenuTile(Icons.lock_outline, 'Đổi mật khẩu', () {}),
              _buildMenuTile(Icons.help_outline, 'Trợ giúp & Hỗ trợ', () {}),

              const SizedBox(height: 10),

              // NÚT ĐĂNG XUẤT
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
                title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cấu hình kết nối API Server',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Địa chỉ Backend ASP.NET Core:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'http://localhost:5000',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Localhost (USB/Emulator)', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'http://localhost:5000',
                ),
                ActionChip(
                  label: const Text('Wi-Fi LAN', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'http://192.168.2.248:5000',
                ),
                ActionChip(
                  label: const Text('Deploy Online', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'https://www.manage365.io.vn',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            onPressed: () {
              setState(() {
                ApiConfig.baseUrl = urlController.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã cập nhật máy chủ: ${ApiConfig.baseUrl}'),
                ),
              );
            },
            child: const Text(
              'Lưu',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textDark),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}