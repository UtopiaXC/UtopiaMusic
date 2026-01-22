import 'dart:math';
import 'package:flutter/material.dart';

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

class SwipeablePlayerCardState extends State<SwipeablePlayerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0.0;
  double _width = 0.0;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleDragStart(DragStartDetails details) {
    if (!widget.enableSwipe || _isAnimatingOut) return;
    setState(() {
      _dragExtent = 0.0;
    });
  }

  void handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enableSwipe || _isAnimatingOut) return;
    setState(() {
      _dragExtent += details.delta.dx;
    });
  }

  void handleDragEnd(DragEndDetails details) {
    if (!widget.enableSwipe || _isAnimatingOut) return;
    
    final velocity = details.primaryVelocity ?? 0;
    final threshold = _width * 0.3;

    if ((_dragExtent > threshold || velocity > 1000) && widget.onPrevious != null) {
      _animateOut(1.0);
    } else if ((_dragExtent < -threshold || velocity < -1000) && widget.onNext != null) {
      _animateOut(-1.0);
    } else {
      _animateBack();
    }
  }

  void _animateBack() {
    _controller.duration = const Duration(milliseconds: 300);
    final start = _dragExtent;
    
    _controller.reset();
    final animation = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    animation.addListener(() {
      setState(() {
        _dragExtent = animation.value;
      });
    });

    _controller.forward();
  }

  void _animateOut(double direction) {
    setState(() {
      _isAnimatingOut = true;
    });
    final end = direction * _width * 1.5;
    final start = _dragExtent;
    
    _controller.duration = const Duration(milliseconds: 200);
    _controller.reset();
    
    final animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

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
      
      // Do NOT reset _dragExtent here immediately.
      // Wait for the widget to update with the new child.
      // The didUpdateWidget method will handle the reset.
    });
  }

  @override
  void didUpdateWidget(SwipeablePlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the child changed (meaning the song changed), we should ensure we are reset.
    if (widget.child.key != oldWidget.child.key) {
       if (_isAnimatingOut) {
         // If we were animating out and the child changed, it means the parent processed the callback.
         // We can now safely reset.
         _controller.stop();
         setState(() {
           _dragExtent = 0.0;
           _isAnimatingOut = false;
         });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        if (_width.isInfinite) {
           _width = MediaQuery.of(context).size.width;
        }
        
        final rotation = _dragExtent / _width * 0.05; // Slight rotation
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
