import 'package:flutter/material.dart';

class ListBuilder extends StatelessWidget {
  final int itemCount;
  final Widget? Function(BuildContext, int) itemBuilder;
  final double itemExtent;
  final Axis scrollDirection;
  final ScrollPhysics? physics;

  const ListBuilder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent = 56.0,
    this.scrollDirection = Axis.vertical,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: scrollDirection,
      physics: physics ?? const BouncingScrollPhysics(),
      itemCount: itemCount,
      itemExtent: scrollDirection == Axis.vertical ? itemExtent : null,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey('list_item_$index'),
          child: itemBuilder(context, index),
        );
      },
      cacheExtent: 500,
    );
  }
}

class MemoizedBuilder<T> extends StatefulWidget {
  final T data;
  final Widget Function(BuildContext, T) builder;
  final bool Function(T, T)? shouldRebuild;

  const MemoizedBuilder({
    super.key,
    required this.data,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<MemoizedBuilder<T>> createState() => _MemoizedBuilderState<T>();
}

class _MemoizedBuilderState<T> extends State<MemoizedBuilder<T>> {
  late T _cachedData;
  late Widget _cachedWidget;

  @override
  void initState() {
    super.initState();
    _cachedData = widget.data;
    _cachedWidget = widget.builder(context, widget.data);
  }

  @override
  void didUpdateWidget(MemoizedBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final shouldUpdate = widget.shouldRebuild != null
        ? widget.shouldRebuild!(_cachedData, widget.data)
        : _cachedData != widget.data;

    if (shouldUpdate) {
      _cachedData = widget.data;
      _cachedWidget = widget.builder(context, widget.data);
    }
  }

  @override
  Widget build(BuildContext context) => _cachedWidget;
}

class ConditionalBuilder extends StatelessWidget {
  final bool condition;
  final Widget Function(BuildContext) builder;
  final Widget Function(BuildContext)? fallback;

  const ConditionalBuilder({
    super.key,
    required this.condition,
    required this.builder,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return condition
        ? builder(context)
        : (fallback != null ? fallback!(context) : const SizedBox.shrink());
  }
}
