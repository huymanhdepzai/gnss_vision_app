import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../controllers/voice_controller.dart';

class VoiceToggleSwitch extends StatefulWidget {
  final double width;
  final double height;

  const VoiceToggleSwitch({Key? key, this.width = 80, this.height = 40})
    : super(key: key);

  @override
  State<VoiceToggleSwitch> createState() => _VoiceToggleSwitchState();
}

class _VoiceToggleSwitchState extends State<VoiceToggleSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(bool isEnabled, VoiceController voiceController) async {
    HapticFeedback.mediumImpact();
    await voiceController.toggleEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceController>(
      builder: (context, voiceController, child) {
        final isEnabled = voiceController.isEnabled;
        final isListening = voiceController.isListening;

        Color enabledColor = AppTheme.successColor;
        Color disabledColor = Colors.grey;
        Color currentColor = isEnabled ? enabledColor : disabledColor;

        Color glowColor = isEnabled
            ? enabledColor.withOpacity(0.3)
            : disabledColor.withOpacity(0.1);

        return GestureDetector(
          onTap: () => _onTap(isEnabled, voiceController),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isEnabled
                    ? [
                        enabledColor.withOpacity(0.2),
                        enabledColor.withOpacity(0.1),
                      ]
                    : [
                        Colors.grey.withOpacity(0.1),
                        Colors.grey.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: isEnabled
                    ? enabledColor.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: isEnabled ? 20 : 5,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: isEnabled ? widget.width - widget.height + 5 : 5,
                  top: 5,
                  child: AnimatedBuilder(
                    animation: isListening
                        ? _controller
                        : const AlwaysStoppedAnimation(1.0),
                    builder: (context, child) {
                      double scale = isListening ? _pulseAnimation.value : 1.0;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: widget.height - 10,
                      height: widget.height - 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [currentColor, currentColor.withOpacity(0.7)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withOpacity(
                              isEnabled ? 0.5 : 0.2,
                            ),
                            blurRadius: isEnabled ? 12 : 5,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isListening
                            ? Icons.mic
                            : (isEnabled ? Icons.mic : Icons.mic_off),
                        color: Colors.white,
                        size: (widget.height - 10) * 0.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
