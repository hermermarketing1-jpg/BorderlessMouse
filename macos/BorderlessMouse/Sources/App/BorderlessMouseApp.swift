import AppKit
import SwiftUI

@main
struct BorderlessMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        Window("BorderlessMouse", id: "main") {
            ContentView().environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 860)

        MenuBarExtra {
            MenuBarView().environmentObject(state)
        } label: {
            Image(systemName: state.cursorOnMac ? "cursorarrow.motionlines.click" : "cursorarrow.motionlines")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.shutdown()
    }
}
