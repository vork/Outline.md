import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Stores the file path if the app is launched via file association before
  /// Flutter is ready to receive method channel calls.
  static var pendingOpenFile: String?

  private var methodChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(
        name: "com.outline.md/file_open",
        binaryMessenger: controller.engine.binaryMessenger
      )

      // Handle Dart asking for the initial file
      methodChannel?.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "getInitialFile" {
          result(AppDelegate.pendingOpenFile)
          AppDelegate.pendingOpenFile = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  /// Called when the user opens a file with this app (double-click, Open With, etc.)
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    if let channel = methodChannel {
      // App is running — send file path to Flutter immediately
      channel.invokeMethod("openFile", arguments: filename)
    } else {
      // App is still launching — store for later
      AppDelegate.pendingOpenFile = filename
    }
    return true
  }
}
