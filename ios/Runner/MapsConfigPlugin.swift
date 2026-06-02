import Flutter
import UIKit

/// Exposes GMSApiKey from Info.plist to Dart for Places / Geocoding REST calls.
final class MapsConfigPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ecl.ecl_commerce/maps_config",
      binaryMessenger: registrar.messenger()
    )
    let instance = MapsConfigPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getGoogleMapsApiKey":
      let key =
        (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      result(key)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
