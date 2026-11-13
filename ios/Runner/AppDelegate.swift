import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase natively before any plugin registers to avoid startup crash
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    GMSServices.provideAPIKey("AIzaSyBvzv4a8LD36X5U1ZSiA3J1FD8R_R3jwFg")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

