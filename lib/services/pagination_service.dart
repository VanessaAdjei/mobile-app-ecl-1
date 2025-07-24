// services/pagination_service.dart
import 'package:flutter/material.dart';

/// Pagination service for handling large data sets efficiently
class PaginationService<T> {
  final List<T> _allItems;
  final int _pageSize;
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMoreData = true;

  PaginationService({
    required List<T> items,
    int pageSize = 20,
  })  : _allItems = items,
        _pageSize = pageSize {
    _hasMoreData = _allItems.length > _pageSize;
  }

  /// Get current page items
  List<T> get currentItems {
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _allItems.length);
    return _allItems.sublist(startIndex, endIndex);
  }

  /// Get all loaded items
  List<T> get allLoadedItems {
    final endIndex = ((_currentPage + 1) * _pageSize).clamp(0, _allItems.length);
    return _allItems.sublist(0, endIndex);
  }

  /// Check if more data is available
  bool get hasMoreData => _hasMoreData;

  /// Check if currently loading
  bool get isLoading => _isLoading;

  /// Get current page number
  int get currentPage => _currentPage;

  /// Get total number of pages
  int get totalPages => (_allItems.length / _pageSize).ceil();

  /// Get total number of items
  int get totalItems => _allItems.length;

  /// Load next page
  Future<List<T>> loadNextPage() async {
    if (_isLoading || !_hasMoreData) {
      return [];
    }

    _isLoading = true;

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    _currentPage++;
    
    final startIndex = _currentPage * _pageSize;
    if (startIndex >= _allItems.length) {
      _hasMoreData = false;
    }

    _isLoading = false;
    return currentItems;
  }

  /// Refresh pagination (reset to first page)
  void refresh() {
    _currentPage = 0;
    _hasMoreData = _allItems.length > _pageSize;
    _isLoading = false;
  }

  /// Jump to specific page
  void jumpToPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      _hasMoreData = _currentPage < totalPages - 1;
    }
  }

  /// Search and filter items
  List<T> search(String query, String Function(T) searchField) {
    if (query.isEmpty) {
      return _allItems;
    }

    return _allItems.where((item) {
      final field = searchField(item).toLowerCase();
      return field.contains(query.toLowerCase());
    }).toList();
  }

  /// Sort items
  void sort(int Function(T, T) compare) {
    _allItems.sort(compare);
    refresh();
  }
}

/// Paginated list view widget
class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final int pageSize;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 20,
    this.loadingWidget,
    this.emptyWidget,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late PaginationService<T> _paginationService;
  final List<T> _displayedItems = [];

  @override
  void initState() {
    super.initState();
    _paginationService = PaginationService<T>(
      items: widget.items,
      pageSize: widget.pageSize,
    );
    _loadInitialData();
  }

  @override
  void didUpdateWidget(PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _paginationService = PaginationService<T>(
        items: widget.items,
        pageSize: widget.pageSize,
      );
      _displayedItems.clear();
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    _displayedItems.addAll(_paginationService.currentItems);
  }

  Future<void> _loadMoreData() async {
    if (_paginationService.isLoading || !_paginationService.hasMoreData) {
      return;
    }

    final newItems = await _paginationService.loadNextPage();
    if (newItems.isNotEmpty) {
      setState(() {
        _displayedItems.addAll(newItems);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const Center(
        child: Text('No items found'),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return false;
      },
      child: ListView.builder(
        controller: widget.scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        itemCount: _displayedItems.length + (_paginationService.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedItems.length) {
            // Loading indicator at the bottom
            return widget.loadingWidget ?? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return widget.itemBuilder(
            context,
            _displayedItems[index],
            index,
          );
        },
      ),
    );
  }
}

/// Paginated grid view widget
class PaginatedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final int pageSize;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const PaginatedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 20,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    this.loadingWidget,
    this.emptyWidget,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  late PaginationService<T> _paginationService;
  final List<T> _displayedItems = [];

  @override
  void initState() {
    super.initState();
    _paginationService = PaginationService<T>(
      items: widget.items,
      pageSize: widget.pageSize,
    );
    _loadInitialData();
  }

  @override
  void didUpdateWidget(PaginatedGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _paginationService = PaginationService<T>(
        items: widget.items,
        pageSize: widget.pageSize,
      );
      _displayedItems.clear();
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    _displayedItems.addAll(_paginationService.currentItems);
  }

  Future<void> _loadMoreData() async {
    if (_paginationService.isLoading || !_paginationService.hasMoreData) {
      return;
    }

    final newItems = await _paginationService.loadNextPage();
    if (newItems.isNotEmpty) {
      setState(() {
        _displayedItems.addAll(newItems);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const Center(
        child: Text('No items found'),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return false;
      },
      child: GridView.builder(
        controller: widget.scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: widget.crossAxisSpacing,
          mainAxisSpacing: widget.mainAxisSpacing,
          childAspectRatio: 0.75,
        ),
        itemCount: _displayedItems.length + (_paginationService.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedItems.length) {
            // Loading indicator at the bottom
            return widget.loadingWidget ?? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return widget.itemBuilder(
            context,
            _displayedItems[index],
            index,
          );
        },
      ),
    );
  }
} 