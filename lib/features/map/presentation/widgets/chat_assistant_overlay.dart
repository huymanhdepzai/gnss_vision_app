import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

class ChatAssistantOverlay extends StatefulWidget {
  final bool isDark;
  final VoidCallback onClose;

  const ChatAssistantOverlay({
    Key? key,
    required this.isDark,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ChatAssistantOverlay> createState() => _ChatAssistantOverlayState();
}

class _ChatAssistantOverlayState extends State<ChatAssistantOverlay> {
  final List<Map<String, String>> _messages = [
    {
      'role': 'bot',
      'text': 'Xin chào! Tôi là trợ lý ảo GNSS. Tôi có thể giúp gì cho bạn?'
    },
  ];

  final List<String> _quickQuestions = [
    'Làm sao để dùng dẫn đường AR?',
    'Xem bản đồ vệ tinh ở đâu?',
    'Làm thế nào để tìm đường?',
    'Ứng dụng này có gì đặc biệt?'
  ];

  final Map<String, String> _answers = {
    'Làm sao để dùng dẫn đường AR?':
        'Bạn chỉ cần chọn một địa điểm, nhấn "Bắt đầu" dẫn đường, sau đó nhấn vào biểu tượng Vision (hình con mắt) để bật chế độ dẫn đường thực tế tăng cường (AR).',
    'Xem bản đồ vệ tinh ở đâu?':
        'Bạn có thể mở menu bên trái (Drawer) và chọn "Bản đồ vệ tinh" hoặc nói lệnh giọng nói "satellite".',
    'Làm thế nào để tìm đường?':
        'Sử dụng thanh tìm kiếm phía trên để nhập điểm đến, sau đó chọn phương tiện và nhấn "Bắt đầu".',
    'Ứng dụng này có gì đặc biệt?':
        'GNSS Vision kết hợp bản đồ Mapbox với công nghệ AR và điều khiển bằng giọng nói để mang lại trải nghiệm dẫn đường hiện đại và an toàn hơn.'
  };

  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  void _handleQuestion(String question) {
    if (_isTyping) return;

    setState(() {
      _messages.add({'role': 'user', 'text': question});
      _isTyping = true;
    });
    _scrollToBottom();

    // Giả lập thời gian suy nghĩ
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'bot',
            'text': _answers[question] ?? 'Xin lỗi, tôi chưa rõ câu hỏi này.'
          });
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppTheme.cardDark : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Trợ lý GNSS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicator(),
                  );
                }
                final msg = _messages[index];
                final isBot = msg['role'] == 'bot';
                return Align(
                  alignment:
                      isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isBot
                          ? (widget.isDark ? Colors.grey[800] : Colors.grey[200])
                          : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomLeft: isBot ? Radius.zero : const Radius.circular(12),
                        bottomRight: isBot ? const Radius.circular(12) : Radius.zero,
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isBot ? textColor : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Quick Questions
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: widget.isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _quickQuestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: ActionChip(
                      label: Text(q),
                      labelStyle: const TextStyle(fontSize: 11),
                      onPressed: () => _handleQuestion(q),
                      backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(
                        ((_controller.value + (index * 0.33)) % 1.0)
                            .clamp(0.2, 1.0),
                      ),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
