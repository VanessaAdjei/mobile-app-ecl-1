# 🎯 Mock API Testing Guide

## ✅ **Ready to Test!**

The clearance sale system is now set up with **mock/dummy data** that simulates real API responses. You can test the complete functionality without needing a real backend!

## 🚀 **How to Test:**

### **Step 1: Run the App**
```bash
flutter run
```

### **Step 2: Test the Admin Panel**
1. Look for the **red floating action button** on the homepage
2. Tap it to open the clearance admin panel
3. Fill in the form:
   - **Sale Name**: `Mega Clearance Sale`
   - **Description**: `Huge discounts on all products!`
   - **Discount Percentage**: `50`
4. Click **"Activate Clearance Sale"**
5. You should see a success message

### **Step 3: Test the Banner**
1. Go back to the homepage
2. You should see a **flashy red banner** with fire emoji 🔥
3. The banner should be animated and eye-catching

### **Step 4: Test the Clearance Homepage**
1. Tap the clearance banner
2. You should see:
   - **Animated banners** at the top
   - **Products with slashed prices** (original price crossed out)
   - **Clearance prices** highlighted in green
   - **Discount percentage badges** on each product
   - **"Load More" button** for pagination

### **Step 5: Test Deactivation**
1. Go back to admin panel
2. Click **"Deactivate Clearance Sale"**
3. Return to homepage - banner should disappear

## 🎨 **What You'll See:**

### **Mock Products Include:**
- Paracetamol 500mg (50% off: GHS 15.00 → GHS 7.50)
- Vitamin C 1000mg (50% off: GHS 25.00 → GHS 12.50)
- Ibuprofen 400mg (50% off: GHS 20.00 → GHS 10.00)
- Multivitamin Complex (50% off: GHS 35.00 → GHS 17.50)
- Calcium 600mg (50% off: GHS 18.00 → GHS 9.00)
- Omega-3 Fish Oil (50% off: GHS 42.00 → GHS 21.00)
- Aspirin 75mg (50% off: GHS 12.00 → GHS 6.00)
- Iron Supplement (50% off: GHS 22.00 → GHS 11.00)

### **Mock Banners:**
- "MEGA CLEARANCE SALE"
- "UP TO 70% OFF"
- "LIMITED TIME DEALS"
- "HURRY UP STOCK LIMITED"

## 🔧 **Mock API Features:**

- ✅ **Simulated API delays** (300-800ms) for realistic feel
- ✅ **Pagination support** (3 pages of products)
- ✅ **Category filtering** (Pain Relief, Vitamins, Supplements)
- ✅ **Realistic product data** with proper pricing
- ✅ **Error handling** and fallback mechanisms
- ✅ **Loading states** and shimmer effects

## 🎯 **Testing Scenarios:**

1. **Activate Sale** → Banner appears on homepage
2. **Tap Banner** → Opens clearance homepage with products
3. **Load More** → Loads additional products (pagination)
4. **Product Cards** → Show slashed prices and discounts
5. **Deactivate Sale** → Banner disappears
6. **App Restart** → Sale state persists (cached locally)

## 🔄 **Switching to Real API:**

When you have your real API ready, just change this line in `lib/services/clearance_sale_api_service.dart`:

```dart
static const bool _useMockData = false; // Change to false
```

And update the API URL:
```dart
static const String _baseUrl = 'https://your-actual-api.com/api';
```

## 🎉 **You're All Set!**

The system is now ready for testing with realistic mock data. You can experience the complete clearance sale functionality without needing any backend infrastructure!

---

**Note**: All mock data is generated locally and simulates real API responses, so you get the full user experience including loading states, animations, and error handling.
