import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBvzv4a8LD36X5U1ZSiA3J1FD8R_R3jwFg")

    // Call super first to ensure FlutterEngine and rootViewController are active
    // so that [self registrarForPlugin:] never returns nil for Swift plugins
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    GeneratedPluginRegistrant.register(with: self)
    return result
  }
}
