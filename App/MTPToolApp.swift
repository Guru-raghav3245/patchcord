import SwiftUI

@main
struct MTPToolApp: App {
    @StateObject private var manager = DeviceManager()

    init() {
        setvbuf(stdout, nil, _IOLBF, 0)  // device log lines show up immediately when redirected
        CLI.runIfRequested()  // exits if a headless command was given
    }

    var body: some Scene {
        WindowGroup { ContentView().environmentObject(manager) }
    }
}
