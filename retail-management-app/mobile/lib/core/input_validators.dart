class InputValidators {
  InputValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(
    String? value, {
    required String requiredMessage,
    String invalidMessage = 'Email không đúng định dạng',
  }) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return requiredMessage;
    if (!_emailPattern.hasMatch(email)) return invalidMessage;
    return null;
  }
}
