import 'dart:math';
import 'package:flutter/material.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SWIPEABLE_PLAYER_CARD";

class SwipeablePlayerCard extends StatefulWidget {
  final Widget child;
  final Widget? previousChild;
  final Widget? nextChild;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final bool enableSwipe;

  const SwipeablePlayerCard({
    super.key,
    required this.child,
    this.previousChild,
    this.nextChild,
    this.onNext,
    this.onPrevious,
    this.enableSwipe = true,
  });

  @override
  State<SwipeablePlayerCard> createState() => SwipeablePlayerCardState();
}

class SwipeablePlayerCardState extends State<SwipeablePlayerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0.0;
  double _width = 0.0;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    Log.v(_tag, "initState");
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _controller.dispose();
    super.dispose();
  }

  void handleDragStart(DragStartDetails details) {
    Log.v(_tag, "handleDragStart, details: $details");
    if (!widget.enableSwipe || _isAnimatingOut) return;
    setState(() {
      _dragExtent = 0.0;
    });
  }

  void handleDragUpdate(DragUpdateDetails details) {
    Log.v(_tag, "handleDragUpdate, details: $details");
    if (!widget.enableSwipe || _isAnimatingOut) return;
    setState(() {
      _dragExtent += details.delta.dx;
    });
  }

  void handleDragEnd(DragEndDetails details) {
    Log.v(_tag, "handleDragEnd, details: $details");
    if (!widget.enableSwipe || _isAnimatingOut) return;

    final velocity = details.primaryVelocity ?? 0;
    final threshold = _width * 0.1;
    const velocityThreshold = 100.0;

    if (widget.onPrevious != null &&
        _dragExtent > 0 &&
        (_dragExtent > threshold || velocity > velocityThreshold)) {
      _animateOut(1.0);
    } else if (widget.onNext != null &&
        _dragExtent < 0 &&
        (_dragExtent < -threshold || velocity < -velocityThreshold)) {
      _animateOut(-1.0);
    } else {
      _animateBack();
    }
  }

  void _animateBack() {
    Log.v(_tag, "_animateBack");
    _controller.duration = const Duration(milliseconds: 300);
    final start = _dragExtent;

    _controller.reset();
    final animation = Tween<double>(
      begin: start,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    animation.addListener(() {
      setState(() {
        _dragExtent = animation.value;
      });
    });

    _controller.forward();
  }

  void _animateOut(double direction) {
    Log.v(_tag, "_animateOut, direction: $direction");
    setState(() {
      _isAnimatingOut = true;
    });
    final end = direction * _width * 1.5;
    final start = _dragExtent;

    _controller.duration = const Duration(milliseconds: 200);
    _controller.reset();

    final animation = Tween<double>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _dragExtent = animation.value;
        });
      }
    });

    _controller.forward().then((_) {
      if (direction > 0) {
        widget.onPrevious?.call();
      } else {
        widget.onNext?.call();
      }
    });
  }

  @override
  void didUpdateWidget(SwipeablePlayerCard oldWidget) {
    Log.v(_tag, "didUpdateWidget, oldWidget: $oldWidget");
    super.didUpdateWidget(oldWidget);
    if (_isAnimatingOut) {
      _controller.stop();
      setState(() {
        _dragExtent = 0.0;
        _isAnimatingOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.v(_tag, "build");
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        if (_width.isInfinite) {
          _width = MediaQuery.of(context).size.width;
        }

        final rotation = _dragExtent / _width * 0.05;
        final progress = min(_dragExtent.abs(), _width) / _width;

        Widget? background;
        if (_dragExtent > 0) {
          background = widget.previousChild;
        } else if (_dragExtent < 0) {
          background = widget.nextChild;
        }

        return GestureDetector(
          onHorizontalDragStart: handleDragStart,
          onHorizontalDragUpdate: handleDragUpdate,
          onHorizontalDragEnd: handleDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (background != null)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 0.9 + (0.1 * progress),
                    child: Opacity(
                      opacity: 0.5 + (0.5 * progress),
                      child: background,
                    ),
                  ),
                ),
              Transform(
                transform: Matrix4.identity()
                  ..translate(_dragExtent)
                  ..rotateZ(rotation),
                alignment: Alignment.center,
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}
