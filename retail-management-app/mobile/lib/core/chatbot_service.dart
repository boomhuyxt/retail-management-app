import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class ChatMessageItem {
  final String role; // 'user' hoặc 'assistant'
  final String text;
  final DateTime timestamp;
  final bool isError;
  final bool isAiActionCard;

  ChatMessageItem({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isError = false,
    this.isAiActionCard = false,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  Map<String, dynamic> toHistoryJson() {
    return {
      'role': role,
      'text': text,
    };
  }

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
    );
  }
}

class ChatBotReply {
  final bool success;
  final String reply;
  final String model;
  final String? timestamp;
  final String? error;

  const ChatBotReply({
    required this.success,
    required this.reply,
    this.model = 'Manage365-AI-Engine',
    this.timestamp,
    this.error,
  });

  factory ChatBotReply.fromJson(Map<String, dynamic> json) {
    return ChatBotReply(
      success: json['success'] == true,
      reply: json['reply'] as String? ?? '',
      model: json['model'] as String? ?? 'Manage365-AI-Engine',
      timestamp: json['timestamp'] as String?,
      error: json['error'] as String?,
    );
  }
}

class ChatTemplateItem {
  final String id;
  final String code;
  final String title;
  final String? filename;
  final String sampleText;

  const ChatTemplateItem({
    required this.id,
    required this.code,
    required this.title,
    this.filename,
    required this.sampleText,
  });

  factory ChatTemplateItem.fromJson(Map<String, dynamic> json) {
    return ChatTemplateItem(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      filename: json['filename'] as String?,
      sampleText: json['sampleText'] as String? ?? '',
    );
  }
}

class ChatbotService {
  /// Gửi tin nhắn đến API Chatbot AI Manage365
  static Future<ChatBotReply> sendMessage({
    required String message,
    List<ChatMessageItem>? history,
    http.Client? client,
  }) async {
    final uri = Uri.parse(ApiConfig.chatbotChatUrl);
    final historyPayload = (history ?? [])
        .where((item) => !item.isError && item.text.trim().isNotEmpty)
        .map((item) => item.toHistoryJson())
        .toList();

    // Giới hạn 10 tin nhắn gần nhất để tối ưu payload và độ trễ
    final trimmedHistory = historyPayload.length > 10
        ? historyPayload.sublist(historyPayload.length - 10)
        : historyPayload;

    final body = jsonEncode({
      'message': message.trim(),
      if (trimmedHistory.isNotEmpty) 'history': trimmedHistory,
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (AuthService.currentToken != null &&
        AuthService.currentToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }

    try {
      final response = await (client != null
              ? client.post(uri, headers: headers, body: body)
              : http.post(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 30));

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && decoded['success'] == true) {
        return ChatBotReply.fromJson(decoded);
      } else {
        final errorMsg = decoded['error'] ??
            decoded['title'] ??
            decoded['message'] ??
            'Không nhận được phản hồi từ AI (${response.statusCode}).';
        return ChatBotReply(
          success: false,
          reply: errorMsg.toString(),
          error: errorMsg.toString(),
        );
      }
    } catch (e) {
      return ChatBotReply(
        success: false,
        reply:
            'Không thể kết nối đến Trợ lý AI Manage365. Vui lòng kiểm tra lại kết nối mạng hoặc thử lại sau.',
        error: e.toString(),
      );
    }
  }

  /// Lấy danh sách 10 biểu mẫu HR chuẩn của Manage365
  static Future<List<ChatTemplateItem>> getTemplates({
    http.Client? client,
  }) async {
    final uri = Uri.parse(ApiConfig.chatbotTemplatesUrl);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (AuthService.currentToken != null &&
          AuthService.currentToken!.isNotEmpty)
        'Authorization': 'Bearer ${AuthService.currentToken}',
    };

    try {
      final response = await (client != null
              ? client.get(uri, headers: headers)
              : http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final list = (decoded['templates'] as List? ?? []);
        return list
            .map((item) =>
                ChatTemplateItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Kiểm tra trạng thái hoạt động của chatbot service
  static Future<bool> checkHealth({http.Client? client}) async {
    final uri = Uri.parse(ApiConfig.chatbotHealthUrl);
    try {
      final response = await (client != null
              ? client.get(uri)
              : http.get(uri))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map && decoded['status'] == 'online';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Gợi ý câu hỏi nhanh dành cho Nhân viên
  static List<String> get employeeSuggestions => [
        'Quy chế xin nghỉ phép trên hệ thống Manage365?',
        'Quy định tính tiền làm thêm giờ (OT) và đổi ca?',
        'Chế độ ốm đau, thai sản BHXH cần giấy tờ gì?',
        'Mẫu đơn xin nghỉ phép chuẩn BM-01',
        'Cách khiếu nại hoặc điều chỉnh giờ chấm công?',
      ];

  /// Gợi ý câu hỏi nhanh dành cho Admin / Quản lý
  static List<String> get adminSuggestions => [
        'Tự động phân công ca làm bằng AI cho tuần này',
        'Quy định định biên nhân sự theo từng khung giờ?',
        'Quy chuẩn nghỉ chuyển ca tối thiểu 12 tiếng',
        'Quy trình xử lý kỷ luật lao động và trách nhiệm vật chất',
        'Cách thiết lập định mức ca làm tối đa cho nhân viên',
      ];
}
