import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // ----------- Siri Shortcut for "Open Finding Buddy" -----------
    let activity = NSUserActivity(activityType: "com.alzahri.findingBuddy.open")
    activity.title = "Open Finding Buddy"
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier =
        NSUserActivityPersistentIdentifier("com.alzahri.findingBuddy.open")

    self.window?.rootViewController?.userActivity = activity
    activity.becomeCurrent()
    // --------------------------------------------------------------
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
