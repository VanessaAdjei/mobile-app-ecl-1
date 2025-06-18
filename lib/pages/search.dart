// pages/search.dart
import 'package:flutter/material.dart';
import 'package:eclapp/pages/itemdetail.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/categories.dart';

class CategorySearchDelegate extends SearchDelegate {
  final List<dynamic> categories;
  final Map<int, List<dynamic>> subcategoriesMap;

  // Cache for search results
  Map<String, List<dynamic>> _searchCache = {};

  CategorySearchDelegate(this.categories, this.subcategoriesMap);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search categories',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Check cache first
    if (_searchCache.containsKey(query)) {
      return _buildResultsList(_searchCache[query]!);
    }

    // Perform search
    final filteredCategories = _performSearch();

    // Cache the result
    _searchCache[query] = filteredCategories;

    return _buildResultsList(filteredCategories);
  }

  List<dynamic> _performSearch() {
    final queryLower = query.toLowerCase();

    return categories.where((category) {
      final categoryName = category['name'].toString().toLowerCase();
      final subcategories = subcategoriesMap[category['id']] ?? [];
      final hasMatchingSubcategory = subcategories.any((subcategory) {
        final subcategoryName = subcategory['name'].toString().toLowerCase();
        return subcategoryName.contains(queryLower);
      });

      return categoryName.contains(queryLower) || hasMatchingSubcategory;
    }).toList();
  }

  Widget _buildResultsList(List<dynamic> filteredCategories) {
    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No categories found matching '$query'",
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        final subcategories = subcategoriesMap[category['id']] ?? [];
        final queryLower = query.toLowerCase();
        final matchingSubcategories = subcategories.where((subcategory) {
          final subcategoryName = subcategory['name'].toString().toLowerCase();
          return subcategoryName.contains(queryLower);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const Divider(height: 1),
            ListTile(
              title: Text(
                category['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: matchingSubcategories.isNotEmpty
                  ? Text(
                      '${matchingSubcategories.length} matching subcategories',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (category['has_subcategories']) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubcategoryPage(
                        categoryName: category['name'],
                        categoryId: category['id'],
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductListPage(
                        categoryName: category['name'],
                        categoryId: category['id'],
                      ),
                    ),
                  );
                }
              },
            ),
            if (matchingSubcategories.isNotEmpty)
              ...matchingSubcategories.map((subcategory) {
                return ListTile(
                  leading: const SizedBox(width: 16),
                  title: Text(
                    subcategory['name'],
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductListPage(
                          categoryName: subcategory['name'],
                          categoryId: subcategory['id'],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
          ],
        );
      },
    );
  }
}
