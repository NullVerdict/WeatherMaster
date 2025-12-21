import 'package:flutter/material.dart';
import '../utils/preferences_helper.dart';

class ScrollReactiveGradient extends StatefulWidget {
  final ScrollController scrollController;
  final LinearGradient baseGradient;
  final LinearGradient scrolledGradient;
  final ValueNotifier<bool>? headerVisibilityNotifier;

  const ScrollReactiveGradient({
    required this.scrollController,
    required this.baseGradient,
    required this.scrolledGradient,
    this.headerVisibilityNotifier,
    super.key,
  });

  @override
  State<ScrollReactiveGradient> createState() => _ScrollReactiveGradientState();
}

class _ScrollReactiveGradientState extends State<ScrollReactiveGradient> {
  late final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
  }

  @override
  void didUpdateWidget(covariant ScrollReactiveGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    _checkScroll();
  }

  void _onScroll() {
    _checkScroll();
  }

  void _checkScroll() {
    final isNowScrolled = widget.scrollController.offset > 300;
    if (_isScrolledNotifier.value != isNowScrolled) {
      _isScrolledNotifier.value = isNowScrolled;
    }

    if (widget.headerVisibilityNotifier != null &&
        widget.headerVisibilityNotifier!.value != isNowScrolled) {
      widget.headerVisibilityNotifier!.value = isNowScrolled;
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useFullMaterialScheme =
        PreferencesHelper.getBool("OnlyMaterialScheme") ?? false;

    return ValueListenableBuilder<bool>(
      valueListenable: _isScrolledNotifier,
      builder: (context, isScrolled, _) {
        return Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isScrolled ? 0 : 1,
              child: RepaintBoundary(
                child: Container(
                    decoration: !useFullMaterialScheme
                        ? BoxDecoration(
                            gradient: widget.baseGradient,
                          )
                        : BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow)),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isScrolled ? 1 : 0,
              child: RepaintBoundary(
                child: Container(
                    decoration: !useFullMaterialScheme
                        ? BoxDecoration(
                            gradient: widget.scrolledGradient,
                          )
                        : BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow)),
              ),
            ),
          ],
        );
      },
    );
  }
}
