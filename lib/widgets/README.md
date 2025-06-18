# Product Card Widgets

This directory contains reusable product card widgets that can be used across different pages in the app.

## Available Widgets

### 1. HomeProductCard
A specialized product card designed for the homepage with compact layout and specific styling.

**Usage:**
```dart
import '../widgets/product_card.dart';

HomeProductCard(
  product: product,
  fontSize: 13,
  padding: 8,
  imageHeight: 95,
  showPrescriptionBadge: true,
  onTap: () {
    // Custom tap handler
  },
)
```

**Parameters:**
- `product` (required): Product object from ProductModel
- `fontSize`: Custom font size for text
- `padding`: Custom padding
- `imageHeight`: Custom image height
- `cardWidth`: Custom card width
- `showPrescriptionBadge`: Whether to show prescription badge (default: true)
- `onTap`: Custom tap handler

### 2. GenericProductCard
A flexible product card that can handle different data formats and be used across all pages.

**Usage:**
```dart
import '../widgets/product_card.dart';

// For Product objects
GenericProductCard(
  product: product,
  showPrice: true,
  showPrescriptionBadge: true,
  showFavoriteButton: false,
)

// For Map data (from API responses)
GenericProductCard(
  product: productMap,
  showPrice: true,
  showPrescriptionBadge: true,
  showFavoriteButton: true,
)
```

**Parameters:**
- `product` (required): Product object or Map<String, dynamic>
- `fontSize`: Custom font size for text
- `padding`: Custom padding
- `imageHeight`: Custom image height
- `cardWidth`: Custom card width
- `showPrescriptionBadge`: Whether to show prescription badge (default: true)
- `onTap`: Custom tap handler
- `showPrice`: Whether to show price (default: true)
- `showFavoriteButton`: Whether to show favorite button (default: false)

## Data Format Support

The `GenericProductCard` supports multiple data formats:

### Product Object (ProductModel)
```dart
Product product = Product(
  id: 1,
  name: "Product Name",
  price: "10.00",
  thumbnail: "image.jpg",
  urlName: "product-url",
  otcpom: "otc",
  // ... other properties
);
```

### Map Format (API Response)
```dart
Map<String, dynamic> productMap = {
  'name': 'Product Name',
  'price': 10.00,
  'thumbnail': 'image.jpg',
  'url_name': 'product-url',
  'otcpom': 'otc',
  // ... other properties
};
```

## Examples

### Homepage Usage
```dart
GridView.builder(
  itemBuilder: (context, index) {
    return HomeProductCard(
      product: products[index],
      fontSize: 13,
      padding: 8,
      imageHeight: 95,
    );
  },
)
```

### Search Results Usage
```dart
GridView.builder(
  itemBuilder: (context, index) {
    return GenericProductCard(
      product: products[index],
      showPrice: true,
      showPrescriptionBadge: true,
    );
  },
)
```

### Categories Page Usage
```dart
GridView.builder(
  itemBuilder: (context, index) {
    return GenericProductCard(
      product: productMap,
      showPrice: true,
      showPrescriptionBadge: true,
      showFavoriteButton: true,
    );
  },
)
```

## Benefits

1. **Consistency**: All product cards across the app will have consistent styling
2. **Maintainability**: Changes to product card design only need to be made in one place
3. **Flexibility**: Different pages can customize the appearance using parameters
4. **Reusability**: Can be used with different data formats
5. **Performance**: Optimized image loading and error handling

## Image URL Handling

The widgets include a `getProductImageUrl` function that handles:
- Full URLs (returns as-is)
- Relative paths (converts to full URL)
- Empty/null URLs (returns empty string)

This ensures consistent image loading across the app. 