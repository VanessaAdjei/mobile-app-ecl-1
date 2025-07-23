// pages/search.dart
import 'package:flutter/material.dart';
import 'package:eclapp/pages/categories.dart';

class CategorySearchDelegate extends SearchDelegate {
  final List<dynamic> categories;
  final Map<int, List<dynamic>> subcategoriesMap;

  // Cache for search results
  final Map<String, List<dynamic>> _searchCache = {};

  // Search history
  final List<String> _searchHistory = [];

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
    if (query.isEmpty) {
      return _buildSearchHistory();
    }
    return _buildSearchResults();
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: _searchHistory.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey.shade600, size: 20),
                SizedBox(width: 8),
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                    _searchHistory.clear();
                    // In a real app, you'd save this to persistent storage
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ),
              ],
            ),
          );
        }

        final historyItem = _searchHistory[index - 1];
        return ListTile(
          leading: Icon(Icons.history, color: Colors.grey.shade400),
          title: Text(historyItem),
          onTap: () {
            query = historyItem;
            showResults(context);
          },
          trailing: IconButton(
            icon: Icon(Icons.close, size: 16),
            onPressed: () {
              _searchHistory.remove(historyItem);
              // In a real app, you'd save this to persistent storage
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Search Categories',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find products by category or subcategory',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '${categories.length} categories available',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return _buildEmptyState();
    }

    // Check cache first
    if (_searchCache.containsKey(query)) {
      return _buildResultsList(_searchCache[query]!);
    }

    // Perform search
    final filteredCategories = _performSearch();

    // Cache the result
    _searchCache[query] = filteredCategories;

    // Add to search history
    if (!_searchHistory.contains(query)) {
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) {
        _searchHistory.removeLast();
      }
    }

    return _buildResultsList(filteredCategories);
  }

  List<dynamic> _performSearch() {
    final queryLower = query.toLowerCase();
    final queryWords =
        queryLower.split(' ').where((word) => word.isNotEmpty).toList();

    return categories.where((category) {
      final categoryName = category['name'].toString().toLowerCase();
      final categoryDescription =
          (category['description'] ?? '').toString().toLowerCase();

      // Check if all query words are found in category name or description
      bool matchesCategory = queryWords.every((word) =>
          categoryName.contains(word) || categoryDescription.contains(word));

      // Check subcategories
      final subcategories = subcategoriesMap[category['id']] ?? [];
      final hasMatchingSubcategory = subcategories.any((subcategory) {
        final subcategoryName = subcategory['name'].toString().toLowerCase();
        final subcategoryDescription =
            (subcategory['description'] ?? '').toString().toLowerCase();

        return queryWords.every((word) =>
            subcategoryName.contains(word) ||
            subcategoryDescription.contains(word));
      });

      return matchesCategory || hasMatchingSubcategory;
    }).toList();
  }

  Widget _buildResultsList(List<dynamic> filteredCategories) {
    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            SizedBox(height: 16),
            Text(
              "No categories found matching '$query'",
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Try different keywords or browse all categories",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
        final queryWords =
            queryLower.split(' ').where((word) => word.isNotEmpty).toList();

        final matchingSubcategories = subcategories.where((subcategory) {
          final subcategoryName = subcategory['name'].toString().toLowerCase();
          final subcategoryDescription =
              (subcategory['description'] ?? '').toString().toLowerCase();

          return queryWords.every((word) =>
              subcategoryName.contains(word) ||
              subcategoryDescription.contains(word));
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const Divider(height: 1),
            _buildCategoryTile(context, category, matchingSubcategories),
            if (matchingSubcategories.isNotEmpty)
              ...matchingSubcategories
                  .map((subcategory) =>
                      _buildSubcategoryTile(context, subcategory))
                  ,
          ],
        );
      },
    );
  }

  Widget _buildCategoryTile(BuildContext context, dynamic category,
      List<dynamic> matchingSubcategories) {
    final isExactMatch =
        category['name'].toString().toLowerCase().contains(query.toLowerCase());

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.category,
          color: Colors.green.shade700,
          size: 20,
        ),
      ),
      title: RichText(
        text: TextSpan(
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 16,
          ),
          children: _highlightText(category['name'], query),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category['description']?.isNotEmpty == true)
            Text(
              category['description'],
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (matchingSubcategories.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '${matchingSubcategories.length} matching subcategories',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      trailing: Icon(
        isExactMatch ? Icons.star : Icons.chevron_right,
        color: isExactMatch ? Colors.amber : Colors.grey.shade400,
        size: isExactMatch ? 20 : 16,
      ),
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
    );
  }

  Widget _buildSubcategoryTile(BuildContext context, dynamic subcategory) {
    return ListTile(
      leading: SizedBox(width: 56),
      title: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 14,
          ),
          children: _highlightText(subcategory['name'], query),
        ),
      ),
      subtitle: subcategory['description']?.isNotEmpty == true
          ? Text(
              subcategory['description'],
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
        size: 16,
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
  }

  List<TextSpan> _highlightText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = textLower.indexOf(queryLower, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.shade200,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return spans;
  }
}
