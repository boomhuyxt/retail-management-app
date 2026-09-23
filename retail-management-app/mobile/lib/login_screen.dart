import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'theme.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmPassCtrl = TextEditingController();

  bool _rememberMe = true;
  bool _obscureLoginPass = true;
  bool _obscureRegPass = true;
  bool _obscureRegConfirmPass = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmPassCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_loginFormKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang xử lý đăng nhập...'),
          duration: Duration(milliseconds: 800),
        ),
      );

      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _handleRegister() {
    if (_registerFormKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký tài khoản thành công!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              children: [
                // Brand Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const FaIcon(FontAwesomeIcons.store, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Retail365', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('HR Management', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const Text('QUẢN TRỊ & CHẤM CÔNG CỬA HÀNG', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 24),

                // Tab Switcher (Đã bỏ Container nền trắng bên ngoài)
                // Tab Switcher - Đã bỏ nền xung quanh & gạch chân
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.transparent, // Bỏ nền kem nhạt bao quanh
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent, // Bỏ đường gạch chân xám ở dưới TabBar
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white, // Chi khi chọn tab mới có nền màu trắng
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE3D1)), // Viền nhạt xung quanh tab active
                    ),
                    labelColor: AppColors.textDark,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(FontAwesomeIcons.rightToBracket, size: 14, color: AppColors.primaryOrange),
                            SizedBox(width: 6),
                            Text('Đăng Nhập'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(FontAwesomeIcons.userPlus, size: 14),
                            SizedBox(width: 6),
                            Text('Đăng Ký'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form Container
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    return IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- FORM ĐĂNG NHẬP ---
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tên đăng nhập / Email *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginUserCtrl,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên đăng nhập hoặc email';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập email hoặc tên đăng nhập...',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Mật khẩu *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginPassCtrl,
            obscureText: _obscureLoginPass,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập mật khẩu...',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_obscureLoginPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // SỬA LỖI OVERFLOW: Bọc phần Checkbox trong Expanded và dùng padding nhỏ hơn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: AppColors.primaryOrange,
                        onChanged: (val) => setState(() => _rememberMe = val!),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text('Ghi nhớ đăng nhập', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {},
                child: const Text('Quên mật khẩu?', style: TextStyle(fontSize: 12, color: Colors.grey)),
              )
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleLogin,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Đăng Nhập', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.black, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          // Divider
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFDCD6D0))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Hoặc đăng nhập bằng', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              Expanded(child: Divider(color: Color(0xFFDCD6D0))),
            ],
          ),
          const SizedBox(height: 16),

          // Google & Facebook Social Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  onPressed: () {},
                  icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red, size: 18),
                  label: const Text('Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  onPressed: () {},
                  icon: const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF1877F2), size: 18),
                  label: const Text('Facebook', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FORM ĐĂNG KÝ ---
  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Họ và tên *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regNameCtrl,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Họ và tên không được để trống';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập họ và tên đầy đủ...',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 12),

          const Text('Email *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email không được để trống';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Định dạng email không hợp lệ';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập địa chỉ email...',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 12),

          const Text('Số điện thoại *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPhoneCtrl,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Số điện thoại không được để trống';
              }
              if (value.trim().length < 10) {
                return 'Số điện thoại phải từ 10 chữ số';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập số điện thoại...',
              icon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 12),

          const Text('Mật khẩu *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPassCtrl,
            obscureText: _obscureRegPass,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Mật khẩu không được để trống';
              }
              if (value.length < 6) {
                return 'Mật khẩu phải từ 6 ký tự trở lên';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập mật khẩu mới...',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_obscureRegPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureRegPass = !_obscureRegPass),
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Text('Xác nhận mật khẩu *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regConfirmPassCtrl,
            obscureText: _obscureRegConfirmPass,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng xác nhận lại mật khẩu';
              }
              if (value != _regPassCtrl.text) {
                return 'Mật khẩu xác nhận không khớp';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Nhập lại mật khẩu...',
              icon: Icons.lock_reset_outlined,
              suffix: IconButton(
                icon: Icon(_obscureRegConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureRegConfirmPass = !_obscureRegConfirmPass),
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleRegister,
              child: const Text('Đăng Ký Tài Khoản', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18),
      suffixIcon: suffix,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: AppColors.bgInput,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1E4D8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1E4D8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }
}