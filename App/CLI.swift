import Foundation

/// Headless commands for testing against a real device. All use the first device's first storage.
///   --probe [/folder]                 list devices, optionally list a folder (with timing)
///   --get /device/path <dir>          download a file or folder
///   --put <local path> /device/folder upload a file or folder ("/" for the root)
///   --cancel-after <seconds>          cancel the --get/--put transfer after a delay
///   --mkdir /device/folder/new        create a folder
///   --rename /device/path newname     rename a file or folder
///   --rm /device/path                 delete a file or folder (recursively)
enum CLI {
    static func runIfRequested() {
        let args = CommandLine.arguments
        func arg(_ flag: String, _ n: Int = 1) -> String? {
            args.firstIndex(of: flag).flatMap { args.count > $0 + n ? args[$0 + n] : nil }
        }
        let commands = ["--probe", "--get", "--put", "--mkdir", "--rename", "--rm"]
        guard args.contains(where: commands.contains) else { return }

        let m = DeviceManager()
        let found = m.scanNow()
        print(found.isEmpty ? "No MTP device attached." : found.map(\.summary).joined(separator: "\n"))
        defer { m.closeAll(); exit(0) }
        guard let d = found.first, let s = d.storages.first else { return }

        do {
            if let path = arg("--probe") {
                let start = Date()
                let entries = try m.list(device: d.id, storage: s.id, folder: try folderID(m, d.id, s.id, path))
                print(String(format: "%@: %d entries in %.2fs", path, entries.count, Date().timeIntervalSince(start)))
                for e in entries.prefix(15) {
                    print("  \(e.isFolder ? "📁" : "  ") \(e.name) | \(e.size) | \(e.kind) | \(e.modified)")
                }
            }
            if let path = arg("--get"), let dir = arg("--get", 2) {
                let e = try entry(m, d.id, s.id, path)
                run(m) { done in m.download(device: d.id, entries: [e], to: URL(fileURLWithPath: dir)) { urls, ok in
                    print("wrote: \(urls.map(\.path)), ok=\(ok)"); done() } }
            }
            if let file = arg("--put"), let path = arg("--put", 2) {
                let folder = try folderID(m, d.id, s.id, path)
                run(m) { done in m.upload(device: d.id, storage: s.id, folder: folder,
                                          files: [URL(fileURLWithPath: file)]) { done() } }
            }
            if let path = arg("--mkdir") {
                let parent = try folderID(m, d.id, s.id, (path as NSString).deletingLastPathComponent)
                op(m) { m.createFolder(device: d.id, storage: s.id, parent: parent,
                                       name: (path as NSString).lastPathComponent, completion: $0) }
            }
            if let path = arg("--rename"), let name = arg("--rename", 2) {
                let e = try entry(m, d.id, s.id, path)
                op(m) { m.rename(device: d.id, entry: e, to: name, completion: $0) }
            }
            if let path = arg("--rm") {
                let e = try entry(m, d.id, s.id, path)
                op(m) { m.delete(device: d.id, entries: [e], completion: $0) }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    /// Runs a file operation whose completion arrives on main, while main is the thread waiting.
    private static func op(_ m: DeviceManager, _ start: (@escaping (String?) -> Void) -> Void) {
        var result: String??
        start { result = $0 }
        while result == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        print(result! ?? "ok")
    }

    private static func entry(_ m: DeviceManager, _ device: String, _ storage: UInt32, _ path: String) throws -> DeviceManager.Entry {
        let parent = try folderID(m, device, storage, (path as NSString).deletingLastPathComponent)
        guard let e = try m.list(device: device, storage: storage, folder: parent)
            .first(where: { $0.name == (path as NSString).lastPathComponent }) else {
            throw DeviceManager.MTPError(errorDescription: "Not found: \(path)")
        }
        return e
    }

    /// Runs a transfer to completion, printing its outcome and throughput.
    private static func run(_ m: DeviceManager, _ start: (@escaping () -> Void) -> Void) {
        let sem = DispatchSemaphore(value: 0)
        let t0 = Date()
        if let delay = CommandLine.arguments.firstIndex(of: "--cancel-after")
            .flatMap({ Double(CommandLine.arguments[$0 + 1]) }) {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { print("cancelling"); m.cancelTransfer() }
        }
        start { sem.signal() }
        sem.wait()
        // Batch status is published on main, which this thread is blocking; read it once main runs.
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let t = m.transfer
        print(String(format: "finished in %.1fs, cancelled=%@, errors=[%@]",
                     Date().timeIntervalSince(t0), String(describing: t?.cancelled ?? false), (t?.errors ?? []).joined(separator: "; ")))
    }

    private static func folderID(_ m: DeviceManager, _ device: String, _ storage: UInt32, _ path: String) throws -> UInt32 {
        var folder = DeviceManager.rootFolder
        for part in path.split(separator: "/") {
            guard let next = try m.list(device: device, storage: storage, folder: folder)
                .first(where: { $0.isFolder && $0.name == part }) else {
                throw DeviceManager.MTPError(errorDescription: "No folder named \(part)")
            }
            folder = next.id
        }
        return folder
    }
}
