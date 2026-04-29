import 'package:flutter/material.dart';
import '../app_theme.dart';

class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final EntranceType type;
  final Curve curve;
  final Offset slideOffset;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = UIConsts.animEntrance,
    this.type = EntranceType.fadeSlideUp,
    this.curve = UIConsts.curveEntrance,
    this.slideOffset = const Offset(0, 0.15),
  });

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    switch (widget.type) {
      case EntranceType.fadeSlideUp:
        _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        _slideAnimation = Tween<Offset>(
          begin: Offset(0, widget.slideOffset.dy),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
        break;

      case EntranceType.fadeSlideLeft:
        _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        _slideAnimation = Tween<Offset>(
          begin: Offset(widget.slideOffset.dx != 0 ? widget.slideOffset.dx : 0.15, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
        break;

      case EntranceType.fadeSlideRight:
        _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        _slideAnimation = Tween<Offset>(
          begin: Offset(widget.slideOffset.dx != 0 ? -widget.slideOffset.dx : -0.15, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
        break;

      case EntranceType.scaleFade:
        _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        break;

      case EntranceType.fadeOnly:
        _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
        break;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

enum EntranceType {
  fadeSlideUp,
  fadeSlideLeft,
  fadeSlideRight,
  scaleFade,
  fadeOnly,
}

class StaggeredListView extends StatelessWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration itemDuration;
  final EntranceType entranceType;
  final Curve curve;
  final EdgeInsets padding;
  final ScrollController? controller;
  final Axis scrollDirection;
  final WrapAlignment wrapAlignment;
  final double spacing;

  const StaggeredListView({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.entranceType = EntranceType.fadeSlideUp,
    this.curve = UIConsts.curveEntrance,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.wrapAlignment = WrapAlignment.start,
    this.spacing = UIConsts.spacingSM,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: scrollDirection,
      controller: controller,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: scrollDirection == Axis.vertical
              ? EdgeInsets.only(bottom: spacing)
              : EdgeInsets.only(right: spacing),
          child: EntranceAnimation(
            delay: interval * index,
            duration: itemDuration,
            type: entranceType,
            curve: curve,
            child: children[index],
          ),
        );
      },
    );
  }
}

class StaggeredGrid extends StatelessWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration itemDuration;
  final EntranceType entranceType;
  final Curve curve;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;

  const StaggeredGrid({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.entranceType = EntranceType.fadeSlideUp,
    this.curve = UIConsts.curveEntrance,
    this.crossAxisCount = 2,
    this.spacing = UIConsts.spacingMD,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return EntranceAnimation(
          delay: interval * index,
          duration: itemDuration,
          type: entranceType,
          curve: curve,
          child: children[index],
        );
      },
    );
  }
}

class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.duration = UIConsts.animFast,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: widget.child,
          );
        },
      ),
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = UIConsts.animNormal,
    this.style,
    this.prefix,
    this.suffix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: widget.value.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _previousValue = widget.value;
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final current = _animation.value.round();
        return Text(
          '${widget.prefix ?? ''}$current${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final Duration duration;
  final TextStyle? style;
  final Curve curve;

  const TypewriterText({
    super.key,
    required this.text,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final charCount = (widget.text.length * _controller.value).round();
        return Text(
          widget.text.substring(0, charCount.clamp(0, widget.text.length)),
          style: widget.style,
        );
      },
    );
  }
}

class BreathingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  const BreathingGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.minOpacity = 0.2,
    this.maxOpacity = 0.6,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
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
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(_animation.value),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

class SlideReveal extends StatefulWidget {
  final Widget child;
  final bool reveal;
  final Duration duration;
  final Axis direction;
  final Curve curve;

  const SlideReveal({
    super.key,
    required this.child,
    required this.reveal,
    this.duration = UIConsts.animNormal,
    this.direction = Axis.vertical,
    this.curve = UIConsts.curveEntrance,
  });

  @override
  State<SlideReveal> createState() => _SlideRevealState();
}

class _SlideRevealState extends State<SlideReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animation);

    if (widget.reveal) _controller.forward();
  }

  @override
  void didUpdateWidget(SlideReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reveal != oldWidget.reveal) {
      if (widget.reveal) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = widget.direction == Axis.vertical
        ? Offset(0, 1 - _animation.value)
        : Offset(1 - _animation.value, 0);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: offset * 20,
        child: widget.child,
      ),
    );
  }
}