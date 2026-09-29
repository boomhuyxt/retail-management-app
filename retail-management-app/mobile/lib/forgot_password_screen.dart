import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/auth_service.dart';
import 'theme.dart';

enum _ResetStep { email, code, password, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  String? _resetToken;
  String? _message;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _runRequest(
      () => AuthService.requestPasswordReset(_emailController.text),
      (result) {
        _step = _ResetStep.code;
        _startResendCountdown();
      },
    );
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _runRequest(
      () => AuthService.verifyResetCode(
        email: _emailController.text,
        code: _codeController.text,
      ),
      (result) {
        if (result.resetToken == null) return;
        _resetToken = result.resetToken;
        _step = _ResetStep.password;
      },
    );
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _runRequest(
      () => AuthService.resetPassword(
        email: _emailController.text,
        resetToken: _resetToken ?? '',
        newPassword: _passwordController.text,
      ),
      (_) => _step = _ResetStep.success,
    );
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;
    await _runRequest(
      () => AuthService.requestPasswordReset(_emailController.text),
      (_) {
        _codeController.clear();
        _startResendCountdown();
      },
    );
  }

  Future<void> _runRequest(
    Future<PasswordResetResult> Function() request,
    void Function(PasswordResetResult result) onSuccess,
  ) async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    final result = await request();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        onSuccess(result);
      } else {
        _message = result.message;
      }
    });
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendSeconds = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds -= 1;
        if (_resendSeconds <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        backgroundColor: AppColors.bgLightCream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_step == _ResetStep.success) return _buildSuccess();
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey(_step),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(_stepIcon, size: 48, color: AppColors.primaryOrange),
          const SizedBox(height: 16),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          if (_message != null) ...[
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_step == _ResetStep.email) _buildEmailField(),
          if (_step == _ResetStep.code) _buildCodeField(),
          if (_step == _ResetStep.password) ..._buildPasswordFields(),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _primaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          if (_step == _ResetStep.code)
            TextButton(
              onPressed: _isLoading || _resendSeconds > 0 ? null : _resendCode,
              child: Text(
                _resendSeconds > 0
                    ? 'Gửi lại mã sau $_resendSeconds giây'
                    : 'Gửi lại mã',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      key: const Key('forgot-email-field'),
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _requestCode(),
      decoration: _decoration('Email tài khoản', Icons.email_outlined),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
          return 'Email không hợp lệ';
        }
        return null;
      },
    );
  }

  Widget _buildCodeField() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: _decoration('Mã xác nhận', Icons.password_outlined),
      validator: (value) =>
          value?.length == 6 ? null : 'Mã xác nhận phải gồm 6 số',
    );
  }

  List<Widget> _buildPasswordFields() {
    return [
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.newPassword],
        decoration: _decoration('Mật khẩu mới', Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        validator: (value) => (value?.length ?? 0) >= 8
            ? null
            : 'Mật khẩu phải có ít nhất 8 ký tự',
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmationController,
        obscureText: _obscureConfirmation,
        autofillHints: const [AutofillHints.newPassword],
        decoration: _decoration('Xác nhận mật khẩu', Icons.lock_reset_outlined)
            .copyWith(
              suffixIcon: IconButton(
                tooltip: _obscureConfirmation ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                icon: Icon(
                  _obscureConfirmation
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
        validator: (value) => value == _passwordController.text
            ? null
            : 'Mật khẩu xác nhận không khớp',
      ),
    ];
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Đổi mật khẩu thành công',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bạn có thể đăng nhập bằng mật khẩu mới.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Quay lại đăng nhập',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.bgInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _primaryAction() {
    return switch (_step) {
      _ResetStep.email => _requestCode(),
      _ResetStep.code => _verifyCode(),
      _ResetStep.password => _resetPassword(),
      _ResetStep.success => Future.value(),
    };
  }

  IconData get _stepIcon => switch (_step) {
    _ResetStep.email => Icons.mark_email_unread_outlined,
    _ResetStep.code => Icons.password_outlined,
    _ResetStep.password => Icons.lock_reset_outlined,
    _ResetStep.success => Icons.check_circle_outline,
  };

  String get _title => switch (_step) {
    _ResetStep.email => 'Quên mật khẩu',
    _ResetStep.code => 'Nhập mã xác nhận',
    _ResetStep.password => 'Tạo mật khẩu mới',
    _ResetStep.success => '',
  };

  String get _description => switch (_step) {
    _ResetStep.email =>
      'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã xác nhận gồm 6 số.',
    _ResetStep.code =>
      'Mã xác nhận đã được gửi nếu email tồn tại trong hệ thống.',
    _ResetStep.password => 'Mật khẩu mới phải có ít nhất 8 ký tự.',
    _ResetStep.success => '',
  };

  String get _buttonLabel => switch (_step) {
    _ResetStep.email => 'Gửi mã xác nhận',
    _ResetStep.code => 'Xác nhận mã',
    _ResetStep.password => 'Cập nhật mật khẩu',
    _ResetStep.success => '',
  };
}
