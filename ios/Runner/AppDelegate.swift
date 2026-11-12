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
      if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let options = FirebaseOptions(contentsOfFile: path) {
        FirebaseApp.configure(options: options)
      } else {
        let options = FirebaseOptions(
          googleAppID: "1:1070966647789:ios:d77684056e9a2722cd95e4",
          gcmSenderID: "1070966647789"
        )
        options.apiKey = "AIzaSyAEy65b4TguhBWPlBorLAA1idO0VG2IQZk"
        options.projectID = "pickleo-67911"
        options.storageBucket = "pickleo-67911.firebasestorage.app"
        FirebaseApp.configure(options: options)
      }
    }

    GMSServices.provideAPIKey("AIzaSyBvzv4a8LD36X5U1ZSiA3J1FD8R_R3jwFg")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

