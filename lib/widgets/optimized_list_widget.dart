// widgets/optimized_list_widget.dart
// widgets/optimized_list_widget.dart
// widgets/optimized_list_widget.dart
// widgets/optimized_list_widget.dart
// widgets/optimized_list_widget.dart
// widgets/optimized_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Optimized ListView with automatic performance optimizations
class OptimizedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final int? itemCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double? itemExtent;
  final double? prototypeItem;
  final bool addSemanticIndexes;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final bool? primary;
  final bool? addAutomaticKeepAlivesOverride;
  final bool? addRepaintBoundariesOverride;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.itemCount,
    this.shrinkWrap = false,
    this.physics,
    this.itemExtent,
    this.prototypeItem,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.primary,
    this.addAutomaticKeepAlivesOverride,
    this.addRepaintBoundariesOverride,
  });

  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  late final ScrollController _scrollController;
  final List<int> _visibleItems = [];
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_isScrolling) {
      setState(() {
        _isScrolling = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: widget.itemCount ?? widget.items.length,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemExtent: widget.itemExtent,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlivesOverride ??
          widget.addAutomaticKeepAlives,
      addRepaintBoundaries:
          widget.addRepaintBoundariesOverride ?? widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      cacheExtent: widget.cacheExtent,
      semanticChildCount: widget.semanticChildCount,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      primary: widget.primary,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return RepaintBoundary(
          child: AutomaticKeepAlive(
            keepAlive: widget.addAutomaticKeepAlives,
            child: widget.itemBuilder(context, item, index),
          ),
        );
      },
    );
  }
}

/// Optimized GridView with automatic performance optimizations
class OptimizedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool addSemanticIndexes;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final bool? primary;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.controller,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.shrinkWrap = false,
    this.physics,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.primary,
  });

  @override
  State<OptimizedGridView<T>> createState() => _OptimizedGridViewState<T>();
}

class _OptimizedGridViewState<T> extends State<OptimizedGridView<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: widget.gridDelegate,
      padding: widget.padding,
      itemCount: widget.items.length,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      cacheExtent: widget.cacheExtent,
      semanticChildCount: widget.semanticChildCount,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      primary: widget.primary,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return RepaintBoundary(
          child: AutomaticKeepAlive(
            keepAlive: widget.addAutomaticKeepAlives,
            child: widget.itemBuilder(context, item, index),
          ),
        );
      },
    );
  }
}

/// Lazy loading list with pagination support
class LazyLoadingList<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) loadData;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final int pageSize;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const LazyLoadingList({
    super.key,
    required this.loadData,
    required this.itemBuilder,
    this.pageSize = 20,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.controller,
    this.padding,
  });

  @override
  State<LazyLoadingList<T>> createState() => _LazyLoadingListState<T>();
}

class _LazyLoadingListState<T> extends State<LazyLoadingList<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasMoreData = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final newItems = await widget.loadData(_currentPage, widget.pageSize);
      setState(() {
        _items.clear();
        _items.addAll(newItems);
        _isLoading = false;
        _hasMoreData = newItems.length >= widget.pageSize;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newItems = await widget.loadData(_currentPage + 1, widget.pageSize);
      setState(() {
        _items.addAll(newItems);
        _currentPage++;
        _isLoading = false;
        _hasMoreData = newItems.length >= widget.pageSize;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    _hasMoreData = true;
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _items.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('Failed to load data'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refresh,
                  child: Text('Retry'),
                ),
              ],
            ),
          );
    }

    if (_items.isEmpty && !_isLoading) {
      return widget.emptyWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('No data available'),
              ],
            ),
          );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: widget.controller ?? _scrollController,
        padding: widget.padding,
        itemCount: _items.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return _buildLoadingIndicator();
          }
          return RepaintBoundary(
            child: widget.itemBuilder(context, _items[index], index),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoading) return SizedBox.shrink();

    return widget.loadingWidget ??
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
  }
}

/// Automatic keep alive wrapper
class AutomaticKeepAlive extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const AutomaticKeepAlive({
    super.key,
    required this.child,
    this.keepAlive = true,
  });

  @override
  State<AutomaticKeepAlive> createState() => _AutomaticKeepAliveState();
}

class _AutomaticKeepAliveState extends State<AutomaticKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
