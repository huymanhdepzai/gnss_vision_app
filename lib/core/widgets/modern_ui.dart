
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../extensions/context_extensions.dart';

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final bool isDark;
  final bool isSmall;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width = double.infinity,
    this.height = UIConsts.buttonHeightLG,
    this.borderRadius = UIConsts.radiusLG,
    this.fontSize = 16,
    this.isDark = true,
    this.isSmall = false,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: UIConsts.animFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final buttonColor = widget.color ?? AppTheme.primaryColor;
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final effectiveHeight = widget.isSmall ? UIConsts.buttonHeightSM : widget.height;
    final effectiveFontSize = widget.isSmall ? 13.0 : widget.fontSize;

    return GestureDetector(
      onTapDown: !isDisabled ? _onTapDown : null,
      onTapUp: !isDisabled ? _onTapUp : null,
      onTapCancel: !isDisabled ? _onTapCancel : null,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: effectiveHeight,
              decoration: widget.isOutlined
                  ? BoxDecoration(
                      border: Border.all(
                        color: buttonColor.withOpacity(isDisabled ? (isDark ? 0.2 : 0.3) : 1.0),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      color: buttonColor.withOpacity(isDark ? 0.06 : 0.04),
                    )
                  : BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          buttonColor,
                          buttonColor.withOpacity(isDark ? 0.85 : 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      boxShadow: !isDisabled
                          ? [
                              BoxShadow(
                                color: buttonColor.withOpacity(isDark ? 0.35 : 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: buttonColor.withOpacity(isDark ? 0.1 : 0.08),
                                blurRadius: 8,
                                offset: const Offset(-2, -2),
                              ),
                            ]
                          : null,
                    ),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isOutlined
                                  ? buttonColor
                                  : Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: widget.isOutlined
                                    ? buttonColor
                                    : Colors.white,
                                size: widget.isSmall ? 16 : 20,
                              ),
                              SizedBox(width: UIConsts.spacingSM),
                            ],
                            Text(
                              widget.text,
                              style: TextStyle(
                                color: widget.isOutlined
                                    ? buttonColor
                                    : Colors.white,
                                fontSize: effectiveFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ModernCard extends StatefulWidget {
  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool hasGlow;
  final double borderRadius;
  final EdgeInsets padding;
  final bool isDark;

  const ModernCard({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.hasGlow = false,
    this.borderRadius = UIConsts.radiusXL,
    this.padding = const EdgeInsets.all(UIConsts.spacingLG),
    this.isDark = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: UIConsts.animFast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final accentColor = widget.accentColor;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _controller.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: accentColor != null
                      ? accentColor.withOpacity(isDark ? 0.15 : 0.12)
                      : (isDark ? Colors.white.withOpacity(0.08) : AppTheme.outlineLight.withOpacity(0.5)),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  if (widget.hasGlow && accentColor != null)
                    BoxShadow(
                      color: accentColor.withOpacity(isDark ? 0.15 : 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ModernTextField extends StatefulWidget {
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final bool enabled;
  final String? errorText;
  final int maxLines;
  final FocusNode? focusNode;

  const ModernTextField({
    super.key,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.controller,
    this.onChanged,
    this.onSuffixTap,
    this.keyboardType,
    this.enabled = true,
    this.errorText,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final primaryColor = AppTheme.primaryColor;
    final bgColor = isDark ? AppTheme.surfaceVariantDark : AppTheme.surfaceVariantLight;
    final borderColor = _isFocused
        ? primaryColor.withOpacity(isDark ? 0.5 : 0.4)
        : (isDark ? Colors.white.withOpacity(0.08) : AppTheme.outlineLight.withOpacity(0.5));
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final hintColor = isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.35);
    final labelColor = _isFocused
        ? primaryColor
        : (isDark ? Colors.white.withOpacity(0.5) : Colors.black54);
    final iconColor = _isFocused
        ? primaryColor
        : (isDark ? Colors.white.withOpacity(0.5) : Colors.black45);
    final errorColor = isDark ? AppTheme.errorDark : AppTheme.errorLight;

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      child: AnimatedContainer(
        duration: UIConsts.animNormal,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(UIConsts.radiusLG),
          border: Border.all(
            color: widget.errorText != null ? errorColor : borderColor,
            width: _isFocused ? 1.5 : 1,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(isDark ? 0.2 : 0.12),
                    blurRadius: 10,
                    spreadRadius: -5,
                  ),
                ]
              : null,
        ),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint,
            labelText: widget.label,
            errorText: widget.errorText,
            hintStyle: TextStyle(color: hintColor, fontSize: 15),
            labelStyle: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: iconColor, size: 20)
                : null,
            suffixIcon: widget.suffixIcon != null
                ? IconButton(
                    icon: Icon(widget.suffixIcon, color: iconColor, size: 20),
                    onPressed: widget.onSuffixTap,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: UIConsts.spacingLG,
              vertical: UIConsts.spacingMD,
            ),
            errorBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class ModernIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double borderRadius;
  final bool isDark;
  final bool useGradient;
  final VoidCallback? onTap;

  const ModernIconContainer({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.iconSize = 22,
    this.borderRadius = UIConsts.radiusLG,
    this.isDark = true,
    this.useGradient = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final decoration = useGradient
        ? AppTheme.iconContainerDecoration(isDark: isDark, color: color, radius: borderRadius)
        : BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(borderRadius),
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: decoration,
        child: Center(
          child: useGradient
              ? ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.7)],
                  ).createShader(bounds),
                  child: Icon(icon, color: Colors.white, size: iconSize),
                )
              : Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

class ModernBadge extends StatelessWidget {
  final String? text;
  final int? count;
  final Color color;
  final double fontSize;
  final bool isDark;

  const ModernBadge({
    super.key,
    this.text,
    this.count,
    this.color = AppTheme.accentColor,
    this.fontSize = 11,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = text ?? (count != null ? (count! > 99 ? '99+' : '$count') : '');
    if (displayText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: text != null ? 8 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(UIConsts.radiusFull),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ModernChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDark;

  const ModernChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.isSelected = false,
    this.onTap,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final chipColor = color ?? AppTheme.primaryColor;
    final bgColor = isSelected
        ? chipColor.withOpacity(isDark ? 0.2 : 0.12)
        : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04));
    final borderColor = isSelected
        ? chipColor.withOpacity(isDark ? 0.3 : 0.25)
        : (isDark ? Colors.white.withOpacity(0.08) : AppTheme.outlineLight.withOpacity(0.4));
    final textColor = isSelected
        ? chipColor
        : (isDark ? Colors.white70 : Colors.black54);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: UIConsts.animNormal,
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: UIConsts.spacingMD,
          vertical: UIConsts.spacingSM - 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(UIConsts.radiusFull),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isSelected
              ? [BoxShadow(color: chipColor.withOpacity(isDark ? 0.15 : 0.08), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 14),
              SizedBox(width: UIConsts.spacingXS),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModernAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final IconData? icon;
  final Color? color;
  final double size;
  final bool isOnline;
  final VoidCallback? onTap;

  const ModernAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.icon,
    this.color,
    this.size = UIConsts.avatarSizeMD,
    this.isOnline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final avatarColor = color ?? AppTheme.primaryColor;
    final radius = size / 2;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [avatarColor, avatarColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: avatarColor.withOpacity(isDark ? 0.3 : 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                BoxShadow(color: avatarColor.withOpacity(isDark ? 0.1 : 0.05), blurRadius: 6, offset: const Offset(-2, -2)),
              ],
            ),
            child: Center(
              child: imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        imageUrl!,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallback(radius),
                      ),
                    )
                  : _buildFallback(radius),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(color: AppTheme.successColor.withOpacity(0.5), blurRadius: 6),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallback(double radius) {
    if (initials != null) {
      return Text(
        initials!,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Icon(icon ?? Icons.person_rounded, color: Colors.white, size: radius);
  }
}

class ModernStatusCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDark;

  const ModernStatusCard({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.white.withOpacity(0.45) : Colors.black45;

    return ModernCard(
      accentColor: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModernIconContainer(icon: icon, color: color, size: 42, iconSize: 20),
              SizedBox(width: UIConsts.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: UIConsts.spacingMD, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(isDark ? 0.2 : 0.12), color.withOpacity(isDark ? 0.06 : 0.03)],
                    ),
                    borderRadius: BorderRadius.circular(UIConsts.radiusSM),
                    border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.15), width: 1),
                  ),
                  child: Text(
                    value!,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ModernProgressBar extends StatefulWidget {
  final double progress;
  final Color? color;
  final double height;
  final double borderRadius;
  final bool showLabel;
  final bool isDark;

  const ModernProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 6,
    this.borderRadius = UIConsts.radiusFull,
    this.showLabel = false,
    this.isDark = true,
  });

  @override
  State<ModernProgressBar> createState() => _ModernProgressBarState();
}

class _ModernProgressBarState extends State<ModernProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: UIConsts.animNormal,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ModernProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final barColor = widget.color ?? AppTheme.primaryColor;
    final trackColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel)
          Padding(
            padding: EdgeInsets.only(bottom: UIConsts.spacingXS),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(widget.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${(widget.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _animation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor, barColor.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      boxShadow: [
                        BoxShadow(color: barColor.withOpacity(0.4), blurRadius: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ModernLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget child;
  final Color? bgColor;
  final bool isDark;

  const ModernLoadingOverlay({
    super.key,
    required this.isLoading,
    this.message,
    required this.child,
    this.bgColor,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final overlayColor = bgColor ?? (isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight);

    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor.withOpacity(0.85),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: UIConsts.spacing2XL,
                  vertical: UIConsts.spacingXL,
                ),
                decoration: AppTheme.cardDecoration(isDark: isDark, accentColor: AppTheme.primaryColor),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                    if (message != null) ...[
                      SizedBox(height: UIConsts.spacingMD),
                      Text(
                        message!,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? color;
  final bool isDark;

  const ModernEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.color,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final themeColor = color ?? AppTheme.primaryColor;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black45;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: UIConsts.spacing2XL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: AppTheme.iconContainerDecoration(
                isDark: isDark,
                color: themeColor,
                radius: UIConsts.radius3XL,
              ),
              child: Icon(icon, color: themeColor, size: 36),
            ),
            SizedBox(height: UIConsts.spacingXL),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: UIConsts.spacingSM),
              Text(
                subtitle!,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              SizedBox(height: UIConsts.spacing2XL),
              ModernButton(
                text: actionText!,
                onPressed: onAction,
                color: themeColor,
                width: 200,
                height: UIConsts.buttonHeightMD,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ModernSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final bool isDark;

  const ModernSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.trailing,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final themeColor = color ?? AppTheme.primaryColor;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black45;

    return Row(
      children: [
        if (icon != null) ...[
          ModernIconContainer(icon: icon!, color: themeColor, size: 36, iconSize: 18),
          SizedBox(width: UIConsts.spacingMD),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w400),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ModernDivider extends StatelessWidget {
  final bool isDark;
  final double indent;
  final double endIndent;

  const ModernDivider({
    super.key,
    this.isDark = true,
    this.indent = UIConsts.spacingLG,
    this.endIndent = UIConsts.spacingLG,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent, vertical: 4),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class ModernDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget content;
  final String? primaryActionText;
  final String? secondaryActionText;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final bool isDanger;
  final bool isDark;

  const ModernDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.content,
    this.primaryActionText,
    this.secondaryActionText,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.isDanger = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final themeColor = isDanger
        ? AppTheme.accentColor
        : (iconColor ?? AppTheme.primaryColor);
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black45;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.maxFinite,
        padding: EdgeInsets.all(UIConsts.spacing2XL),
        decoration: AppTheme.cardDecoration(isDark: isDark, accentColor: themeColor),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ModernIconContainer(icon: icon!, color: themeColor, size: 56, iconSize: 28),
              SizedBox(height: UIConsts.spacingLG),
            ],
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: UIConsts.spacingSM),
              Text(
                subtitle!,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: UIConsts.spacingLG),
            content,
            if (primaryActionText != null || secondaryActionText != null) ...[
              SizedBox(height: UIConsts.spacingXL),
              Row(
                children: [
                  if (secondaryActionText != null)
                    Expanded(
                      child: ModernButton(
                        text: secondaryActionText!,
                        onPressed: onSecondaryAction ?? () => Navigator.pop(context),
                        isOutlined: true,
                        color: isDark ? Colors.white70 : AppTheme.textDark,
                        height: UIConsts.buttonHeightMD,
                      ),
                    ),
                  if (secondaryActionText != null && primaryActionText != null)
                    SizedBox(width: UIConsts.spacingMD),
                  if (primaryActionText != null)
                    Expanded(
                      child: ModernButton(
                        text: primaryActionText!,
                        onPressed: onPrimaryAction,
                        color: isDanger ? AppTheme.accentColor : themeColor,
                        height: UIConsts.buttonHeightMD,
                      ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ModernBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color? accentColor;
  final bool showHandle;
  final bool isDark;

  const ModernBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.accentColor,
    this.showHandle = true,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final themeColor = accentColor;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - topPadding - 40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(UIConsts.radius3XL)),
        border: Border.all(
          color: themeColor != null
              ? themeColor.withOpacity(isDark ? 0.15 : 0.1)
              : (isDark ? Colors.white.withOpacity(0.08) : AppTheme.outlineLight),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -10)),
          if (themeColor != null)
            BoxShadow(color: themeColor.withOpacity(isDark ? 0.1 : 0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(UIConsts.radius3XL)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: UIConsts.spacingMD),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: themeColor != null
                          ? LinearGradient(colors: [themeColor, themeColor.withOpacity(0.6)])
                          : LinearGradient(colors: isDark
                              ? [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)]
                              : [AppTheme.primaryColor.withOpacity(0.3), AppTheme.primaryColor.withOpacity(0.1)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(UIConsts.spacing2XL, 0, UIConsts.spacing2XL, UIConsts.spacingLG),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(UIConsts.spacingSM),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(UIConsts.radiusSM),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white54 : Colors.black45,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlideGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()..translate(slidePercent * bounds.width);
  }
}

class PulseWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

class GlowEffect extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;

  const GlowEffect({
    super.key,
    required this.child,
    required this.glowColor,
    this.blurRadius = 20,
    this.spreadRadius = -5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.4),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

class FloatingWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double verticalOffset;

  const FloatingWidget({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.verticalOffset = 10.0,
  });

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -widget.verticalOffset / 2,
      end: widget.verticalOffset / 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}