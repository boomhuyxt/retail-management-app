import 'package:flutter/material.dart';
import 'theme.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isEditing = false;

  // Controllers cho các trường thông tin
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _empIdController;
  late TextEditingController _roleController;
  late TextEditingController _dobController;
  late TextEditingController _startDateController;

  String _gender = 'Nữ';

  @override
  void initState() {
    super.initState();
    // Giả lập dữ liệu hiện tại từ hệ thống
    _nameController = TextEditingController(text: 'Quỳnh');
    _emailController = TextEditingController(text: 'balldinhnguyen140905@gmail.com');
    _phoneController = TextEditingController(text: '0987 654 321');
    _empIdController = TextEditingController(text: 'NV001');
    _roleController = TextEditingController(text: 'Nhân viên bán hàng');
    _dobController = TextEditingController(text: '14/09/2005');
    _startDateController = TextEditingController(text: '01/03/2026');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _empIdController.dispose();
    _roleController.dispose();
    _dobController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thông Tin Cá Nhân',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit_outlined,
              color: AppColors.primaryOrange,
            ),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Lưu thông tin
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật thông tin cá nhân!')),
                  );
                }
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- 1. AVATAR & NÚT ĐỔI ẢNH ---
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.shade100,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: Xử lý chọn ảnh từ thư viện
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _nameController.text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _roleController.text,
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. KHUNG THÔNG TIN CHI TIẾT ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoField(
                    label: 'Họ và tên',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    enabled: _isEditing,
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoField(
                    label: 'Mã nhân viên',
                    controller: _empIdController,
                    icon: Icons.badge_outlined,
                    enabled: false, // Mã nhân viên không cho sửa
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoField(
                    label: 'Email',
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    enabled: _isEditing,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoField(
                    label: 'Số điện thoại',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  _buildGenderSelector(),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoField(
                    label: 'Ngày sinh',
                    controller: _dobController,
                    icon: Icons.cake_outlined,
                    enabled: _isEditing,
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoField(
                    label: 'Ngày vào làm',
                    controller: _startDateController,
                    icon: Icons.calendar_today_outlined,
                    enabled: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- 3. NÚT NỔI LƯU THAY ĐỔI (KHI Ở CHẾ ĐỘ SỬA) ---
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật thông tin cá nhân!')),
                    );
                  },
                  child: const Text(
                    'Lưu thay đổi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Widget dòng thông tin
  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              enabled
                  ? TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                ),
              )
                  : Text(
                controller.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textDark : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget chọn Giới tính
  Widget _buildGenderSelector() {
    return Row(
      children: [
        const Icon(Icons.wc_outlined, color: AppColors.primaryOrange, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giới tính',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              _isEditing
                  ? Row(
                children: [
                  ChoiceChip(
                    label: const Text('Nam', style: TextStyle(fontSize: 12)),
                    selected: _gender == 'Nam',
                    selectedColor: AppColors.primaryOrange.withOpacity(0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _gender = 'Nam');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Nữ', style: TextStyle(fontSize: 12)),
                    selected: _gender == 'Nữ',
                    selectedColor: AppColors.primaryOrange.withOpacity(0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _gender = 'Nữ');
                    },
                  ),
                ],
              )
                  : Text(
                _gender,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}