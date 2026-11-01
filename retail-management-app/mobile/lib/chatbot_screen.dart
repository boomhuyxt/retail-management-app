import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/auth_service.dart';
import 'core/chatbot_service.dart';
import 'theme.dart';

class ChatbotScreen extends StatefulWidget {
  final VoidCallback? onOpenAiScheduler;

  const ChatbotScreen({super.key, this.onOpenAiScheduler});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageItem> _messages = [];

  bool _isSending = false;
  List<ChatTemplateItem> _templates = [];
  bool _isLoadingTemplates = false;

  UserModel? get _user => AuthService.currentUser;

  bool get _isAdminOrManager {
    final role = (_user?.role ?? '').toLowerCase();
    return role.contains('admin') ||
        role.contains('manager') ||
        role.contains('owner') ||
        role.contains('chủ cửa hàng');
  }

  @override
  void initState() {
    super.initState();
    _initChat();
    _loadTemplates();
  }

  void _initChat() {
    final name = _user?.displayName.isNotEmpty == true
        ? _user!.displayName
        : 'bạn';

    String welcomeText =
        'Xin chào $name! 👋 Tôi là Trợ lý AI Nội bộ Manage365.\n\n'
        'Tôi sẵn sàng hỗ trợ bạn tra cứu quy chế công ty, thủ tục xin nghỉ phép, '
        'chế độ bảo hiểm y tế/thai sản/ốm đau, quy định đổi ca làm việc và tính tiền làm thêm giờ (OT).';

    if (_isAdminOrManager) {
      welcomeText +=
          '\n\nVới quyền Quản trị / Quản lý, bạn cũng có thể yêu cầu tôi hướng dẫn '
          'quy chuẩn định biên hoặc sử dụng tính năng **Phân ca tự động bằng AI**.';
    }

    _messages.add(
      ChatMessageItem(
        role: 'assistant',
        text: welcomeText,
      ),
    );
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    final list = await ChatbotService.getTemplates();
    if (mounted) {
      setState(() {
        _templates = list;
        _isLoadingTemplates = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (overrideText == null) {
      _inputController.clear();
    }

    final userMessage = ChatMessageItem(role: 'user', text: text);
    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });
    _scrollToBottom();

    final response = await ChatbotService.sendMessage(
      message: text,
      history: _messages,
    );

    if (!mounted) return;

    setState(() {
      _isSending = false;
      _messages.add(
        ChatMessageItem(
          role: 'assistant',
          text: response.reply,
          isError: !response.success,
          isAiActionCard: _isAdminOrManager &&
              (text.toLowerCase().contains('phân ca') ||
                  text.toLowerCase().contains('xếp ca') ||
                  text.toLowerCase().contains('lịch làm')),
        ),
      );
    });
    _scrollToBottom();
  }

  void _showTemplatesModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined,
                        color: AppColors.primaryOrange),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Biểu mẫu Hành chính Nhân sự',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoadingTemplates
                    ? const Center(child: CircularProgressIndicator())
                    : _templates.isEmpty
                        ? const Center(
                            child: Text(
                              'Không tải được danh sách biểu mẫu.\nVui lòng kiểm tra lại kết nối mạng.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _templates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _templates[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ExpansionTile(
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrange
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey.shade200),
                                            ),
                                            constraints: const BoxConstraints(
                                                maxHeight: 200),
                                            child: SingleChildScrollView(
                                              child: SelectableText(
                                                item.sampleText,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.copy,
                                                    size: 16),
                                                label: const Text(
                                                    'Sao chép biểu mẫu'),
                                                onPressed: () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                        text: item.sampleText),
                                                  );
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Đã sao chép ${item.code} vào bộ nhớ tạm'),
                                                      duration: const Duration(
                                                          seconds: 2),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _isAdminOrManager
        ? ChatbotService.adminSuggestions
        : ChatbotService.employeeSuggestions;

    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryOrange, Color(0xFFFF8A65)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trợ lý AI Manage365',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _isAdminOrManager
                              ? 'Chế độ Quản trị & Phân ca AI'
                              : 'Hỗ trợ Nhân sự trực tuyến 24/7',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Biểu mẫu HR',
            icon: const Icon(Icons.description_outlined,
                color: AppColors.primaryOrange),
            onPressed: _showTemplatesModal,
          ),
          IconButton(
            tooltip: 'Làm mới cuộc trò chuyện',
            icon: const Icon(Icons.restart_alt, color: Colors.grey),
            onPressed: () {
              setState(() {
                _messages.clear();
                _initChat();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Gợi ý câu hỏi nhanh
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = suggestions[index];
                  return ActionChip(
                    backgroundColor: AppColors.bgLightCream,
                    side: BorderSide(color: Colors.orange.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    label: Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => _handleSendMessage(prompt),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // Khung hiển thị danh sách tin nhắn
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            // Thanh nhập tin nhắn
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessageItem msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 18,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryOrange
                        : (msg.isError ? Colors.red.shade50 : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: msg.isError
                        ? Border.all(color: Colors.red.shade200)
                        : null,
                  ),
                  child: SelectableText(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: isUser
                          ? Colors.white
                          : (msg.isError
                              ? Colors.red.shade900
                              : AppColors.textDark),
                    ),
                  ),
                ),
                if (!isUser && msg.isAiActionCard) ...[
                  const SizedBox(height: 8),
                  _buildAiScheduleActionCard(),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (!isUser && !msg.isError) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép phản hồi vào bộ nhớ tạm'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(Icons.copy, size: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiScheduleActionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primaryOrange, size: 18),
              SizedBox(width: 8),
              Text(
                'AI Tự Động Phân Ca Làm Việc',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hệ thống AI sẽ tối ưu định biên theo giờ, số ca tối đa và tránh vi phạm luật lao động.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text(
              'Mở Bảng Phân Ca Bằng AI',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (widget.onOpenAiScheduler != null) {
                Navigator.pop(context);
                widget.onOpenAiScheduler!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy,
              size: 18,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Trợ lý AI đang suy nghĩ...',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Chọn mẫu đơn',
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: _showTemplatesModal,
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendMessage(),
              decoration: const InputDecoration(
                hintText: 'Nhập câu hỏi hoặc yêu cầu...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Gửi tin nhắn',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
            ),
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            onPressed: _isSending ? null : () => _handleSendMessage(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
