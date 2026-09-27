import SwiftUI

@main
struct MTPToolApp: App {
    @StateObject private var manager = DeviceManager()

    init() {
        setvbuf(stdout, nil, _IOLBF, 0)  // device log lines show up immediately when redirected
        CLI.runIfRequested()  // exits if a headless command was given
        Theme.registerFonts()
        #if DEBUG
        // UI check without Screen Recording permission: MTPTOOL_SNAPSHOT=/path.png [MTPTOOL_APPEARANCE=dark|light]
        // [MTPTOOL_SNAPSHOT_DELAY=s] saves the window's own rendering once.
        let env = ProcessInfo.processInfo.environment
        if let look = env["MTPTOOL_APPEARANCE"] {
            DispatchQueue.main.async { NSApp.appearance = NSAppearance(named: look == "dark" ? .darkAqua : .aqua) }
        }
        if let out = env["MTPTOOL_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(env["MTPTOOL_SNAPSHOT_DELAY"] ?? "") ?? 5)) {
                guard let view = NSApp.windows.first(where: \.isVisible)?.contentView?.superview,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return print("[snapshot] no window") }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                print("[snapshot] \(out)")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView().environmentObject(manager) }
            .windowStyle(.hiddenTitleBar)  // content runs under the traffic lights, like the website's full-bleed header
    }
}
