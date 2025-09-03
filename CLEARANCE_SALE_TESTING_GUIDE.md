# 🧪 Clearance Sale Testing Guide

## 🎯 **Quick Test (No API Required)**

### Step 1: Run the App
```bash
flutter run
```

### Step 2: Access Admin Panel
- Look for the **red floating action button** on the homepage
- Tap it to open the clearance admin panel

### Step 3: Activate a Test Sale
Fill in the form:
- **Sale Name**: `Mega Clearance Sale`
- **Description**: `Huge discounts on all products!`
- **Discount Percentage**: `50`
- Click **"Activate Clearance Sale"**

### Step 4: Test the Banner
- Go back to the homepage
- You should see a **flashy red banner** with fire emoji
- The banner should be animated and eye-catching

### Step 5: Test Clearance Homepage
- Tap the clearance banner
- You should see a dedicated clearance homepage with:
  - Animated banners
  - Products with slashed prices
  - Discount percentages
  - "Load More" functionality

### Step 6: Test Deactivation
- Go back to admin panel
- Click **"Deactivate Clearance Sale"**
- Return to homepage - banner should disappear

## 🔧 **Testing with Real API**

### Step 1: Update API URL
In `lib/services/clearance_sale_api_service.dart`:
```dart
static const String _baseUrl = 'https://your-actual-api.com/api';
```

### Step 2: Test API Endpoints
Use tools like Postman or curl to test:

```bash
# Check if clearance sale is active
curl -X GET "https://your-api.com/api/clearance/check"

# Get clearance products
curl -X GET "https://your-api.com/api/clearance/products?page=1&limit=20"

# Activate clearance sale
curl -X POST "https://your-api.com/api/clearance/activate" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Sale",
    "description": "Test description",
    "discount_percentage": 30,
    "applicable_categories": ["Pain Relief"],
    "excluded_products": [],
    "end_date": null
  }'
```

## 🐛 **Troubleshooting**

### Issue: Banner Not Showing
- Check if clearance sale is activated in admin panel
- Verify the provider is initialized in main.dart
- Check console for any errors

### Issue: Products Not Loading
- The system falls back to mock data if API fails
- Check network connectivity
- Verify API endpoint URLs

### Issue: Admin Panel Not Working
- Ensure the floating action button is visible
- Check if the route is properly configured in main.dart

## 📱 **Expected User Flow**

1. **App Launch** → Provider checks for active clearance sales
2. **Homepage** → Shows clearance banner if sale is active
3. **Banner Tap** → Opens clearance homepage with discounted products
4. **Product View** → Shows original price crossed out, clearance price highlighted
5. **Admin Control** → Can activate/deactivate sales via floating button

## 🎨 **Visual Features to Test**

- ✅ Animated clearance banner with fire emoji
- ✅ Pulsing discount percentage
- ✅ Slashed original prices
- ✅ Highlighted clearance prices
- ✅ Discount percentage badges
- ✅ Load more functionality
- ✅ Shimmer loading states
- ✅ Error handling with retry options

## 📊 **Performance Testing**

- Test with slow network connections
- Test with API failures (should fallback gracefully)
- Test pagination with large product lists
- Test offline functionality (cached data)

## 🔐 **Security Testing**

- Test admin authentication (when implemented)
- Test input validation in admin forms
- Test API rate limiting
- Test data sanitization

---

**Note**: The system is designed to work even without an API, using mock data as fallback. This allows you to test the complete user experience before implementing the backend.
