# Store Proximity Sorting Feature

## Overview
The store locator now includes proximity-based sorting functionality that allows users to find stores nearest to their current location. This feature enhances the user experience by showing the most relevant stores first.

## Features

### 🔍 **Location-Based Sorting**
- **Distance Calculation**: Automatically calculates the distance between user's location and each store
- **Smart Sorting**: Sorts stores by proximity when "Distance" option is selected
- **Fallback Coordinates**: Uses estimated coordinates for major Ghanaian cities when exact coordinates aren't available

### 📍 **Location Services**
- **Permission Handling**: Gracefully requests location permissions
- **Location Caching**: Caches user location for 5 minutes to avoid repeated requests
- **Error Handling**: Provides fallback options when location services are unavailable

### 🎯 **Sorting Options**
1. **Name**: Alphabetical sorting by store name
2. **Distance**: Proximity-based sorting (requires location permission)
3. **Rating**: Sorting by store rating (highest first)

## Implementation Details

### Location Service (`lib/services/location_service.dart`)
```dart
class LocationService {
  // Singleton pattern for efficient resource usage
  static final LocationService _instance = LocationService._internal();
  
  // Cached location with 5-minute expiry
  Position? _cachedUserLocation;
  DateTime? _lastLocationUpdate;
  
  // Key methods:
  Future<Position?> getCurrentLocation()
  double calculateDistance(double lat1, double lon1, double lat2, double lon2)
  String formatDistance(double distanceInKm)
}
```

### Store Location Page Updates (`lib/pages/storelocation.dart`)
- Added location initialization on page load
- Implemented sorting logic with distance calculation
- Added sorting UI with chips for different sort options
- Enhanced store cards to display distance information

### Distance Calculation
The system uses the Haversine formula (via `Geolocator.distanceBetween()`) to calculate accurate distances between coordinates.

### Fallback Coordinates
When store coordinates aren't available in the API response, the system uses estimated coordinates for major Ghanaian cities:
- Accra: 5.5600, -0.2057
- Kumasi: 6.6885, -1.6244
- Tamale: 9.4035, -0.8423
- Sekondi/Takoradi: 4.9340, -1.7300
- Sunyani: 7.3399, -2.3268
- Ho: 6.6000, 0.4700
- Koforidua: 6.0833, -0.2500
- Cape Coast: 5.1053, -1.2466

## User Experience

### Location Permission Flow
1. User opens store locator
2. System checks location availability
3. If not available, shows "Enable location to sort by distance" prompt
4. User can tap "Enable" to request permissions
5. Once granted, "Distance" sorting option becomes available

### Sorting Interface
- **Sort Chips**: Horizontal scrollable chips for different sort options
- **Visual Feedback**: Selected sort option is highlighted in green
- **Distance Display**: Shows formatted distance (e.g., "2.3km", "450m") on store cards
- **Location Icon**: Small location icon next to distance for visual clarity

### Distance Formatting
- **Under 1km**: Shows in meters (e.g., "450m")
- **1-10km**: Shows with 1 decimal place (e.g., "2.3km")
- **Over 10km**: Shows rounded to nearest kilometer (e.g., "15km")

## Technical Requirements

### Dependencies
- `geolocator: ^10.1.0` - Location services
- `geocoding: ^2.1.1` - Address geocoding (for future enhancements)

### Permissions
The app already includes the necessary location permissions in:
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

### Performance Considerations
- **Location Caching**: 5-minute cache reduces API calls
- **Efficient Sorting**: Distance calculations are performed only when needed
- **Fallback Handling**: Graceful degradation when location services are unavailable

## Future Enhancements

### Potential Improvements
1. **Real-time Location Updates**: Continuous location tracking for dynamic sorting
2. **Custom Distance Ranges**: Filter stores within specific distance ranges
3. **Route Planning**: Integration with navigation apps for directions
4. **Store Clustering**: Group nearby stores for better map display
5. **Offline Support**: Cache store locations for offline distance calculations

### API Integration
If the backend API is updated to include store coordinates, the system will automatically use the exact coordinates instead of estimated ones.

## Testing

### Test Scenarios
1. **Location Available**: Verify distance sorting works correctly
2. **Location Denied**: Verify fallback to name sorting
3. **Location Services Disabled**: Verify graceful error handling
4. **No Coordinates in API**: Verify estimated coordinates are used
5. **Mixed Coordinates**: Verify both exact and estimated coordinates work together

### Manual Testing Steps
1. Open the store locator
2. Grant location permissions when prompted
3. Select "Distance" sorting option
4. Verify stores are sorted by proximity
5. Check distance display on store cards
6. Test other sorting options (Name, Rating)

## Troubleshooting

### Common Issues
1. **Location not working**: Check device location services and app permissions
2. **Distance not showing**: Verify location permissions are granted
3. **Incorrect distances**: May be due to estimated coordinates - check if API provides exact coordinates
4. **Sorting not updating**: Try refreshing the page or toggling sort options

### Debug Information
The implementation includes comprehensive debug logging:
- Location acquisition status
- Distance calculation results
- Sorting method used
- Coordinate source (API vs estimated)

## Conclusion

The proximity-based store sorting feature significantly improves the user experience by helping customers find the nearest stores quickly. The implementation is robust, handles edge cases gracefully, and provides a smooth user experience even when location services are unavailable. 