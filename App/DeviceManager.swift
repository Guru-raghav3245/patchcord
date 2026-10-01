import AppKit
import IOKit
import UniformTypeIdentifiers

/// Tracks connected MTP devices. Every detected device is kept open (one session each)
/// until it disappears or the app quits; the picker only switches which one is active.
final class DeviceManager: ObservableObject {
    struct Storage: Identifiable {
        let id: UInt32
        let name: String
        let capacity: UInt64
        let free: UInt64
    }

    struct Device: Identifiable {
        let id: String      // "bus-devnum": unique per connection
        let name: String
        let storages: [Storage]
        let error: String?  // set when the device was detected but couldn't be opened
        var connecting = false  // detected, session still opening (a stuck device takes ~65 s to fail)
    }

    struct Entry: Identifiable {
        let id: UInt32
        let storage: UInt32
        let name: String
        let size: UInt64
        let isFolder: Bool
        let modified: Date
        let kind: String
    }

    struct MTPError: LocalizedError {
        let errorDescription: String?
    }

    static let rootFolder: UInt32 = 0xFFFF_FFFF  // LIBMTP_FILES_AND_FOLDERS_ROOT

    @Published private(set) var devices: [Device] = []
    @Published var activeID: String?

    var active: Device? { devices.first { $0.id == activeID } }

    /// Brief "connected" / "disconnected" message, shown as a snackbar.
    struct Notice: Equatable {
        let id = UUID()
        let text: String
        let connected: Bool  // lit LED
    }
    @Published var notice: Notice?
    private var scannedOnce = false  // no notice for the devices already plugged in at launch

    // Transfer state (see Transfers.swift). Stored here because extensions can't add stored properties.
    @Published var transfer: TransferStatus?
    @Published var listingVersion = 0  // bumped after transfers so the browser reloads
    let cancelLock = NSLock()
    var cancelRequested = false  // guarded by cancelLock
    var lastReportedFraction = 0.0  // mtp queue only

    // ponytail: one serial queue for every libmtp call; per-device queues if concurrent multi-device transfers matter
    let mtp = DispatchQueue(label: "mtp")
    var handles: [String: UnsafeMutablePointer<LIBMTP_mtpdevice_t>] = [:]  // mtp queue only
    private var watcher: USBWatcher?
    private var pending: DispatchWorkItem?

    init() {
        mtp.async { LIBMTP_Init() }
        watcher = USBWatcher(queue: .main) { [weak self] in self?.scheduleRescan() }
        #if DEBUG
        if ProcessInfo.processInfo.environment["PATCHCORD_FAKE_NOTICE"] != nil {  // UI check of the snackbar
            notice = Notice(text: "Music Player connected", connected: true)
        }
        if ProcessInfo.processInfo.environment["PATCHCORD_FAKE_TRANSFER"] != nil {  // UI check of the transfer bar
            transfer = TransferStatus(verb: "Uploading", count: 12, index: 2, name: "03 Aagaya Gangai - Dheem Dhira.flac",
                                      fraction: 0.62, totalBytes: 612_000_000, doneBytes: 118_000_000, currentBytes: 48_000_000)
        }
        #endif
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: nil) { [weak self] _ in self?.closeAll() }
    }

    /// Debounced: a single plug event fires several USB notifications, and the device needs a moment to settle.
    func scheduleRescan(after delay: TimeInterval = 1) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.mtp.async {
                guard let self else { return }
                let found = self.rescan { detected in DispatchQueue.main.async { self.showConnecting(detected) } }
                DispatchQueue.main.async { self.publish(found) }
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Synchronous scan for `--probe`.
    func scanNow() -> [Device] { mtp.sync { rescan { _ in } } }

    /// Lists one folder. Blocks on the mtp queue, so call it off the main thread.
    func list(device: String, storage: UInt32, folder: UInt32) throws -> [Entry] {
        try mtp.sync {
            guard let h = handles[device] else { throw MTPError(errorDescription: "The device was disconnected.") }
            return try listFolder(h, storage: storage, folder: folder)
        }
    }

    /// mtp queue only.
    func listFolder(_ h: UnsafeMutablePointer<LIBMTP_mtpdevice_t>, storage: UInt32, folder: UInt32) throws -> [Entry] {
        dispatchPrecondition(condition: .onQueue(mtp))
        LIBMTP_Clear_Errorstack(h)
        var entries: [Entry] = []
        var next = LIBMTP_Get_Files_And_Folders(h, storage, folder)
        while let f = next {
            let name = f.pointee.filename.map { String(cString: $0) } ?? ""
            let isFolder = f.pointee.filetype == LIBMTP_FILETYPE_FOLDER
            let kind = isFolder ? "Folder"
                : UTType(filenameExtension: (name as NSString).pathExtension)?.localizedDescription ?? "Document"
            entries.append(Entry(id: f.pointee.item_id, storage: f.pointee.storage_id, name: name, size: f.pointee.filesize, isFolder: isFolder,
                                 modified: Date(timeIntervalSince1970: TimeInterval(f.pointee.modificationdate)),
                                 kind: kind))
            next = f.pointee.next
            LIBMTP_destroy_file_t(f)
        }
        // libmtp returns NULL for both "empty folder" and "failed"; only the error stack tells them apart.
        if entries.isEmpty, LIBMTP_Get_Errorstack(h) != nil {
            LIBMTP_Clear_Errorstack(h)
            throw MTPError(errorDescription: "Couldn't read this folder from the device.")
        }
        return entries
    }

    func closeAll() {
        mtp.sync {
            handles.values.forEach { LIBMTP_Release_Device($0) }
            handles.removeAll()
        }
    }

    /// Shows devices that are still opening, so the window doesn't say "No device connected" meanwhile.
    private func showConnecting(_ detected: [(id: String, name: String)]) {
        devices = detected.map { d in
            devices.first { $0.id == d.id && !$0.connecting && $0.error == nil }
                ?? Device(id: d.id, name: d.name, storages: [], error: nil, connecting: true)
        }
        if active == nil { activeID = devices.first?.id }
    }

    private func publish(_ found: [Device]) {
        let shown = devices.filter { !$0.connecting }  // placeholders were never announced
        let added = found.filter { d in !shown.contains { $0.id == d.id } }.map(\.name)
        let removed = shown.filter { d in !found.contains { $0.id == d.id } }.map(\.name)
        if scannedOnce, !added.isEmpty || !removed.isEmpty {
            let list = { (names: [String]) in ListFormatter.localizedString(byJoining: names) }
            let text = [added.isEmpty ? nil : "\(list(added)) connected",
                        removed.isEmpty ? nil : "\(list(removed)) disconnected"].compactMap { $0 }.joined(separator: " · ")
            let n = Notice(text: text, connected: !added.isEmpty)
            notice = n
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.notice == n { self?.notice = nil }
            }
        }
        scannedOnce = true
        devices = found
        if active == nil { activeID = found.first?.id }
        print("[devices] " + (found.isEmpty ? "none" : found.map(\.summary).joined(separator: "; ")))
    }

    // MARK: - mtp queue

    /// `detected` is called before opening any new device, with everything found on the bus.
    private func rescan(detected: ([(id: String, name: String)]) -> Void) -> [Device] {
        dispatchPrecondition(condition: .onQueue(mtp))
        var raw: UnsafeMutablePointer<LIBMTP_raw_device_t>?
        var n: Int32 = 0
        let err = LIBMTP_Detect_Raw_Devices(&raw, &n)
        defer { free(raw) }
        let raws = err == LIBMTP_ERROR_NONE && raw != nil
            ? Array(UnsafeBufferPointer(start: raw, count: Int(n))) : []

        let ids = raws.map { "\($0.bus_location)-\($0.devnum)" }
        for (id, handle) in handles where !ids.contains(id) {  // unplugged
            LIBMTP_Release_Device(handle)
            handles[id] = nil
        }
        if ids.contains(where: { handles[$0] == nil }) {
            detected(zip(ids, raws).map { ($0, Self.name(of: $1)) })
        }

        return zip(ids, raws).map { id, r in
            var r = r
            // A quick replug can reuse the same bus-devnum, leaving us a dead session: drop it and reopen.
            if let h = handles[id], LIBMTP_Get_Storage(h, 0) != 0 {
                LIBMTP_Release_Device(h)
                handles[id] = nil
            }
            if handles[id] == nil, let h = Self.open(&r) {
                LIBMTP_Get_Storage(h, 0)
                handles[id] = h
            }
            guard let h = handles[id] else {
                return Device(id: id, name: Self.name(of: r), storages: [], error: Self.openError(r))
            }
            let name = [LIBMTP_Get_Friendlyname(h), LIBMTP_Get_Modelname(h)].lazy
                .compactMap(Self.take).first { !$0.isEmpty } ?? Self.name(of: r)
            return Device(id: id, name: name, storages: Self.storages(h), error: nil)
        }
    }

    /// Reads the storage list already fetched by LIBMTP_Get_Storage.
    private static func storages(_ h: UnsafeMutablePointer<LIBMTP_mtpdevice_t>) -> [Storage] {
        return sequence(first: h.pointee.storage, next: { $0?.pointee.next }).compactMap { s in
            s.map { s in
                Storage(id: s.pointee.id,
                        name: s.pointee.StorageDescription.map { String(cString: $0) } ?? "Storage",
                        capacity: s.pointee.MaxCapacity, free: s.pointee.FreeSpaceInBytes)
            }
        }
    }

    private static func name(of r: LIBMTP_raw_device_t) -> String {
        let e = r.device_entry
        if let v = e.vendor, let p = e.product { return "\(String(cString: v)) \(String(cString: p))" }
        return String(format: "USB device %04x:%04x", e.vendor_id, e.product_id)
    }

    /// Some phones (e.g. Redmi A5) report their MTP interface as a camera, so macOS's ptpcamerad (behind Photos and
    /// Image Capture) claims it on plug-in. launchd relaunches ptpcamerad within a second of it quitting, so stop it
    /// and reopen as soon as it lets go; once we hold the interface it can't take it back.
    private static func open(_ r: inout LIBMTP_raw_device_t) -> Handle? {
        if let h = LIBMTP_Open_Raw_Device_Uncached(&r) { return h }
        let (vendor, product) = (r.device_entry.vendor_id, r.device_entry.product_id)
        guard let owner = usbExclusiveOwner(vendor: vendor, product: product), owner.name == "ptpcamerad" else { return nil }
        print("[devices] taking \(name(of: r)) from ptpcamerad (pid \(owner.pid))")
        kill(owner.pid, SIGKILL)
        var waits = 0  // until the kernel has released its claim, at most 0.5 s
        while waits < 50, usbExclusiveOwner(vendor: vendor, product: product)?.pid == owner.pid {
            usleep(10_000)
            waits += 1
        }
        return LIBMTP_Open_Raw_Device_Uncached(&r)
    }

    private static func openError(_ r: LIBMTP_raw_device_t) -> String {
        if let owner = usbExclusiveOwner(vendor: r.device_entry.vendor_id, product: r.device_entry.product_id) {
            let name = owner.name == "ptpcamerad" ? "Photos / Image Capture" : owner.name
            return "In use by \(name). Quit it, then click Retry."
        }
        return "Couldn't open the device. Unplug and replug it, and check its USB mode is File transfer."
    }

    /// libmtp returns malloc'd strings the caller must free.
    private static func take(_ p: UnsafeMutablePointer<CChar>?) -> String? {
        guard let p else { return nil }
        defer { free(p) }
        return String(cString: p)
    }
}

extension DeviceManager.Device {
    var summary: String {
        if let error { return "\(name) [\(id)]: \(error)" }
        let gb = { (n: UInt64) in String(format: "%.1f GB", Double(n) / 1e9) }
        return "\(name) [\(id)]: " + storages.map { "\($0.name) \(gb($0.free)) free of \(gb($0.capacity))" }
            .joined(separator: ", ")
    }
}

/// The other process holding exclusive access to a USB device or one of its interfaces, if any: e.g. MacDroid
/// or Android File Transfer (device), or macOS's ptpcamerad (the MTP interface of phones that report it as a camera).
/// macOS exposes it as "pid 123, AppName" in the UsbExclusiveOwner property.
func usbExclusiveOwner(vendor: UInt16, product: UInt16) -> (pid: pid_t, name: String)? {
    let match = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
    match["idVendor"] = vendor
    match["idProduct"] = product
    var it: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &it) == KERN_SUCCESS else { return nil }
    defer { IOObjectRelease(it) }
    while case let dev = IOIteratorNext(it), dev != 0 {
        defer { IOObjectRelease(dev) }
        var it2: io_iterator_t = 0
        IORegistryEntryCreateIterator(dev, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &it2)
        var children: [io_object_t] = []
        while case let c = IOIteratorNext(it2), c != 0 { children.append(c) }
        IOObjectRelease(it2)
        defer { children.forEach { IOObjectRelease($0) } }
        for entry in [dev] + children {
            guard let owner = IORegistryEntryCreateCFProperty(entry, "UsbExclusiveOwner" as CFString,
                                                              kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            else { continue }
            let parts = owner.components(separatedBy: ", ")  // "pid 123, AppName"
            guard let pid = parts.first.flatMap({ pid_t($0.dropFirst(4)) }), pid != getpid() else { continue }
            return (pid, parts.dropFirst().joined(separator: ", "))
        }
    }
    return nil
}

/// Calls `onChange` whenever any USB device is attached or removed.
final class USBWatcher {
    private let port: IONotificationPortRef
    private let onChange: () -> Void
    private var iterators: [io_iterator_t] = []

    init(queue: DispatchQueue, onChange: @escaping () -> Void) {
        self.onChange = onChange
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, queue)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var it: io_iterator_t = 0
            IOServiceAddMatchingNotification(port, type, IOServiceMatching("IOUSBHostDevice"), { ctx, it in
                USBWatcher.drain(it)
                Unmanaged<USBWatcher>.fromOpaque(ctx!).takeUnretainedValue().onChange()
            }, ctx, &it)
            USBWatcher.drain(it)  // draining arms the notification; first-match also reports already-attached devices
            iterators.append(it)
        }
        onChange()
    }

    private static func drain(_ it: io_iterator_t) {
        while case let s = IOIteratorNext(it), s != 0 { IOObjectRelease(s) }
    }
}
