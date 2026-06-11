import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
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
    final bgColor = widget.isDark
        ? AppTheme.cardDark.withOpacity(0.9)
        : Colors.white.withOpacity(0.9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 320,
          height: 450,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isDark ? Colors.white10 : Colors.black12,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildChatArea(),
              ),
              _buildQuickQuestions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/bot-svg.svg',
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn),
                  width: 24,
                  height: 24,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trợ lý GNSS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Đang trực tuyến',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return const _MessageBubble(
            text: '',
            isBot: true,
            isTyping: true,
          );
        }
        final msg = _messages[index];
        return _MessageBubble(
          text: msg['text']!,
          isBot: msg['role'] == 'bot',
        );
      },
    );
  }

  Widget _buildQuickQuestions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black
            .withOpacity(0.02),
        border: Border(
          top: BorderSide(
            color: widget.isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Gợi ý câu hỏi',
              style: TextStyle(
                color: widget.isDark ? Colors.white60 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                textBaseline: TextBaseline.alphabetic,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickQuestions.length,
              itemBuilder: (context, index) {
                final q = _quickQuestions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(q),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    onPressed: () => _handleQuestion(q),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    side: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isBot;
  final bool isTyping;

  const _MessageBubble({
    Key? key,
    required this.text,
    required this.isBot,
    this.isTyping = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          crossAxisAlignment: isBot
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery
                    .of(context)
                    .size
                    .width * 0.6,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isBot
                    ? null
                    : LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: isBot
                    ? (isDark ? Colors.grey[850] : Colors.grey[100])
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isBot ? 4 : 20),
                  bottomRight: Radius.circular(isBot ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isTyping
                  ? const TypingIndicator()
                  : Text(
                text,
                style: TextStyle(
                  color: isBot
                      ? (isDark ? Colors.white.withOpacity(0.9) : Colors
                      .black87)
                      : Colors.white,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
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
    )
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(
                  ((_controller.value + (index * 0.33)) % 1.0)
                      .clamp(0.2, 1.0),
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
