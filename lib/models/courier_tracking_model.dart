/// Optional courier / live-tracking payload (Phase 2). Populated when the API
/// returns rider fields on the order snapshot.
class CourierTrackingModel {
  const CourierTrackingModel({
    this.name,
    this.phone,
    this.vehicle,
    this.latitude,
    this.longitude,
    this.lastUpdatedAt,
    this.note,
  });

  final String? name;
  final String? phone;
  final String? vehicle;
  final double? latitude;
  final double? longitude;
  final DateTime? lastUpdatedAt;
  final String? note;

  bool get hasIdentity =>
      (name?.isNotEmpty ?? false) ||
      (phone?.isNotEmpty ?? false) ||
      (vehicle?.isNotEmpty ?? false);

  bool get hasLiveLocation => latitude != null && longitude != null;

  factory CourierTrackingModel.fromSnapshot(Map<String, dynamic> snapshot) {
    double? lat;
    double? lng;
    final latRaw = snapshot['courier_lat'] ?? snapshot['rider_lat'];
    final lngRaw = snapshot['courier_lng'] ?? snapshot['rider_lng'];
    if (latRaw is num) lat = latRaw.toDouble();
    if (lngRaw is num) lng = lngRaw.toDouble();

    DateTime? updated;
    final updatedRaw = snapshot['courier_updated_at']?.toString();
    if (updatedRaw != null && updatedRaw.isNotEmpty) {
      updated = DateTime.tryParse(updatedRaw);
    }

    return CourierTrackingModel(
      name: snapshot['courier_name']?.toString(),
      phone: snapshot['courier_phone']?.toString(),
      vehicle: snapshot['courier_vehicle']?.toString(),
      latitude: lat,
      longitude: lng,
      lastUpdatedAt: updated,
      note: snapshot['live_tracking_note']?.toString(),
    );
  }
}
