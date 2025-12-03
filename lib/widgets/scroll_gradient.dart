import 'package:flutter/material.dart';

class ScrollReactiveGradient extends StatefulWidget {
  final ScrollController scrollController;
  final LinearGradient baseGradient;
  final LinearGradient scrolledGradient;
  final ValueNotifier<bool> headerVisibilityNotifier;

  const ScrollReactiveGradient({
    super.key,
    required this.scrollController,
    required this.baseGradient,
    required this.scrolledGradient,
    required this.headerVisibilityNotifier,
  });

  @override
  State<ScrollReactiveGradient> createState() => _ScrollReactiveGradientState();
}

class _ScrollReactiveGradientState extends State<ScrollReactiveGradient> {
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _scrollProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = widget.scrollController.offset;
    final threshold = 200.0;
    final progress = (offset / threshold).clamp(0.0, 1.0);
    
    if (_scrollProgress.value != progress) {
      _scrollProgress.value = progress;
      
      final showHeader = offset > 100;
      if (widget.headerVisibilityNotifier.value != showHeader) {
        widget.headerVisibilityNotifier.value = showHeader;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollProgress,
        builder: (context, progress, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(
                    widget.baseGradient.colors[0],
                    widget.scrolledGradient.colors[0],
                    progress,
                  )!,
                  Color.lerp(
                    widget.baseGradient.colors[1],
                    widget.scrolledGradient.colors[1],
                    progress,
                  )!,
                ],
                begin: widget.baseGradient.begin,
                end: widget.baseGradient.end,
              ),
            ),
          );
        },
      ),
    );
  }
}
