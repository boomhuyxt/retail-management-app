import 'package:flutter/material.dart';
import '../chatbot_screen.dart';
import '../theme.dart';

class ChatbotFloatingBubble extends StatefulWidget {
  final VoidCallback? onOpenAiScheduler;

  const ChatbotFloatingBubble({super.key, this.onOpenAiScheduler});

  @override
  State<ChatbotFloatingBubble> createState() => _ChatbotFloatingBubbleState();
}

class _ChatbotFloatingBubbleState extends State<ChatbotFloatingBubble>
    with SingleTickerProviderStateMixin {
  Offset? _position;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(
          onOpenAiScheduler: widget.onOpenAiScheduler,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Vị trí mặc định: Góc dưới bên trái, phía trên BottomNavigationBar
    // để tránh trùng với FloatingActionButton của Quản lý ở góc phải
    final defaultPos = Offset(
      16,
      screenSize.height - padding.bottom - 150,
    );
    final pos = _position ?? defaultPos;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final newX = (pos.dx + details.delta.dx).clamp(
              8.0,
              screenSize.width - 68.0,
            );
            final newY = (pos.dy + details.delta.dy).clamp(
              padding.top + 10.0,
              screenSize.height - padding.bottom - 110.0,
            );
            _position = Offset(newX, newY);
          });
        },
        onPanEnd: (_) {
          // Tự động hít (snap) về mép trái hoặc mép phải màn hình
          final currentX = pos.dx;
          final snapX = currentX < (screenSize.width / 2)
              ? 16.0
              : screenSize.width - 72.0;
          setState(() {
            _position = Offset(snapX, pos.dy);
          });
        },
        onTap: _openChatbot,
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFFF8A65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                // Chấm xanh báo hiệu online
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                // Huy hiệu chữ AI nhỏ
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
