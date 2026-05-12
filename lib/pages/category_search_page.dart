import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../widgets/ecl_expandable_sliver_app_bar.dart';

// --- Data Models ---
class Category {
  final String id;
  final String name;
  final List<SubCategory> subCategories;
  Category({required this.id, required this.name, required this.subCategories});
}

class SubCategory {
  final String id;
  final String name;
  final String categoryId;
  SubCategory({required this.id, required this.name, required this.categoryId});
}

class Item {
  final String name;
  final String categoryId;
  final String subCategoryId;
  Item(
      {required this.name,
      required this.categoryId,
      required this.subCategoryId});
}

// --- Providers & Indexes ---
final categoriesProvider =
    Provider<List<Category>>((ref) => []); // Fill with your data
final itemsProvider = Provider<List<Item>>((ref) => []); // Fill with your data

final byCategoryProvider = Provider<Map<String, List<Item>>>((ref) {
  final items = ref.watch(itemsProvider);
  final map = <String, List<Item>>{};
  for (final item in items) {
    map.putIfAbsent(item.categoryId, () => []).add(item);
  }
  return map;
});

final bySubCategoryProvider = Provider<Map<String, List<Item>>>((ref) {
  final items = ref.watch(itemsProvider);
  final map = <String, List<Item>>{};
  for (final item in items) {
    map.putIfAbsent(item.subCategoryId, () => []).add(item);
  }
  return map;
});

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedSubCategoryProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredItemsProvider = Provider<List<Item>>((ref) {
  final byCategory = ref.watch(byCategoryProvider);
  final bySubCategory = ref.watch(bySubCategoryProvider);
  final catId = ref.watch(selectedCategoryProvider);
  final subId = ref.watch(selectedSubCategoryProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  List<Item> items = [];
  if (subId != null && bySubCategory.containsKey(subId)) {
    items = bySubCategory[subId]!;
  } else if (catId != null && byCategory.containsKey(catId)) {
    items = byCategory[catId]!;
  }
  if (query.isNotEmpty) {
    items =
        items.where((item) => item.name.toLowerCase().contains(query)).toList();
  }
  return items;
});

// --- Debounced Search Widget ---
class CategorySearchPage extends ConsumerStatefulWidget {
  const CategorySearchPage({Key? key}) : super(key: key);
  @override
  ConsumerState<CategorySearchPage> createState() => _CategorySearchPageState();
}

class _CategorySearchPageState extends ConsumerState<CategorySearchPage> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final filteredItems = ref.watch(filteredItemsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedSubCategory = ref.watch(selectedSubCategoryProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const EclExpandableSliverAppBar(
            toolbarTitle: 'Category Search',
            heroTitle: 'Category search',
            heroSubtitle: 'Filter items by category',
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                DropdownButton<String?>(
                  value: selectedCategory,
                  hint: const Text('Select Category'),
                  isExpanded: true,
                  items: categories
                      .map((cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.name),
                          ))
                      .toList(),
                  onChanged: (catId) {
                    ref.read(selectedCategoryProvider.notifier).state = catId;
                    ref.read(selectedSubCategoryProvider.notifier).state = null;
                  },
                ),
                const SizedBox(height: 12),
                if (selectedCategory != null)
                  DropdownButton<String?>(
                    value: selectedSubCategory,
                    hint: const Text('Select Subcategory'),
                    isExpanded: true,
                    items: categories
                        .firstWhere((cat) => cat.id == selectedCategory)
                        .subCategories
                        .map((sub) => DropdownMenuItem(
                              value: sub.id,
                              child: Text(sub.name),
                            ))
                        .toList(),
                    onChanged: (subId) {
                      ref.read(selectedSubCategoryProvider.notifier).state =
                          subId;
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          if (filteredItems.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No items found.')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, idx) {
                  final item = filteredItems[idx];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                        'Category: ${item.categoryId}, Sub: ${item.subCategoryId}'),
                  );
                },
                childCount: filteredItems.length,
              ),
            ),
        ],
      ),
    );
  }
}
