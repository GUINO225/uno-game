import 'dart:async';

import 'package:flutter/material.dart';

class BouncyCardEntry extends StatefulWidget {
  const BouncyCardEntry({
    super.key,
    required this.child,
    this.animate = false,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutBack,
    this.startScale = 0,
    this.peakScale = 1.08,
  });

  final Widget child;
  final bool animate;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final double startScale;
  final double peakScale;

  @override
  State<BouncyCardEntry> createState() => _BouncyCardEntryState();
}

class _BouncyCardEntryState extends State<BouncyCardEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.animate ? 0 : 1,
    );
    _configureAnimation();
    if (widget.animate) {
      _playBounce();
    }
  }

  @override
  void didUpdateWidget(covariant BouncyCardEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.startScale != widget.startScale || oldWidget.peakScale != widget.peakScale) {
      _configureAnimation();
    }
    if (!oldWidget.animate && widget.animate) {
      _playBounce();
    }
  }

  void _configureAnimation() {
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: widget.startScale, end: widget.peakScale)
            .chain(CurveTween(curve: widget.curve)),
        weight: 60,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: widget.peakScale, end: 1).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 40,
      ),
    ]).animate(_controller);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: Curves.easeOut),
    );
  }

  void _playBounce() {
    _startTimer?.cancel();
    _controller.value = 0;
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _startTimer = Timer(widget.delay, () {
      if (!mounted) {
        return;
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
