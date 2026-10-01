import SwiftUI
import UniformTypeIdentifiers

// Look: DESIGN.md "the faceplate" (graphite / paper, engraved mono labels, one amber light), matching the website.

struct ContentView: View {
    @EnvironmentObject var manager: DeviceManager

    var body: some View {
        Group {
            if manager.devices.isEmpty {
                NoDeviceView()
            } else if let device = manager.active {
                if device.connecting {
                    ConnectingView(device: device)
                } else if let error = device.error {
                    DeviceErrorView(device: device, error: error)
                } else {
                    BrowserView(device: device).id(device.id)  // fresh browser state per device
                }
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let n = manager.notice {
                Snackbar(notice: n).padding(.bottom, manager.transfer == nil ? 28 : 120)  // clear the transfer bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: manager.notice)
    }
}

/// Device connected / disconnected notice: a small faceplate panel with the indicator light.
private struct Snackbar: View {
    let notice: DeviceManager.Notice
    var body: some View {
        HStack(spacing: 10) {
            LED(lit: notice.connected)
            Text(notice.text).font(Theme.sans(13, .medium)).foregroundColor(Theme.text).lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .accessibilityHidden(true)  // announced by DeviceManager instead
    }
}

/// Status line + device name, shared by the browser and the error screen. Clears the hidden title bar's traffic lights.
private struct DeviceHeader<Trailing: View>: View {
    @EnvironmentObject var manager: DeviceManager
    let name: String
    let status: String
    var led = Theme.amber
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                LED(color: led)
                EngravedLabel(status)
            }
            HStack(alignment: .firstTextBaseline) {
                if manager.devices.count > 1 {
                    DeviceMenu(name: name)
                } else {
                    Text(name).font(Theme.serif(38)).foregroundColor(Theme.text).lineLimit(1)
                }
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(BrushedMetal().ignoresSafeArea(.all, edges: .top))  // grain continues behind the traffic lights
        .overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .bottom)
    }
}

/// With more than one device connected, the device name itself is the switcher.
private struct DeviceMenu: View {
    @EnvironmentObject var manager: DeviceManager
    let name: String
    @State private var hover = false
    var body: some View {
        Menu {
            Picker("Device", selection: $manager.activeID) {
                ForEach(manager.devices) { Text($0.name).tag(Optional($0.id)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            // One Text: a menu button puts a separate image before its title, so the chevron is inline instead.
            let chevron = Text(Image(systemName: "chevron.down")).font(.system(size: 14, weight: .semibold))
                .foregroundColor(hover ? Theme.amberInk : Theme.muted)
            Text("\(Text(name).font(Theme.serif(38)).foregroundColor(Theme.text))  \(chevron)").lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hover = $0 }
        .help("Switch device")
        .accessibilityLabel("Device: \(name)")
    }
}

/// The website hero's faint vertical grain.
private struct BrushedMetal: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Canvas { ctx, size in
            let c = scheme == .dark ? Color.white.opacity(0.018) : Color.black.opacity(0.02)
            for x in stride(from: 0, to: size.width, by: 3) {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(c))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct NoDeviceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) { LED(lit: false); EngravedLabel("No device connected") }
            Text("Plug it in.").font(Theme.serif(64)).foregroundColor(Theme.text)
            Text("Connect a music player or Android phone over USB, and set its USB mode to File transfer. It shows up here on its own.")
                .font(Theme.sans(16)).foregroundColor(Theme.muted).frame(maxWidth: 440, alignment: .leading)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(BrushedMetal().ignoresSafeArea())
    }
}

private struct ConnectingView: View {
    let device: DeviceManager.Device
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeviceHeader(name: device.name, status: "Connecting", led: Theme.muted) { ProgressView().controlSize(.small) }
            Text("Opening the device. A device that has stopped responding takes about a minute to give up.")
                .font(Theme.sans(16)).foregroundColor(Theme.muted).frame(maxWidth: 480, alignment: .leading)
                .padding(24)
            Spacer()
        }
    }
}

private struct DeviceErrorView: View {
    @EnvironmentObject var manager: DeviceManager
    let device: DeviceManager.Device
    let error: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeviceHeader(name: device.name, status: "Can't open", led: Theme.err) { EmptyView() }
            VStack(alignment: .leading, spacing: 20) {
                Text(error).font(Theme.sans(16)).foregroundColor(Theme.text).frame(maxWidth: 480, alignment: .leading)
                Button("Retry") { manager.scheduleRescan(after: 0) }.buttonStyle(.faceplatePrimary)
            }
            .padding(24)
            Spacer()
        }
    }
}

private struct BrowserView: View {
    typealias Entry = DeviceManager.Entry

    @EnvironmentObject var manager: DeviceManager
    let device: DeviceManager.Device

    @State private var storageID: UInt32?
    @State private var path: [Entry] = []  // folders opened below the storage root
    @State private var entries: [Entry] = []
    @State private var loading = false
    @State private var error: String?
    @State private var selection = Set<UInt32>()
    @State private var sortOrder = [KeyPathComparator(\Entry.name, comparator: .localizedStandard)]
    @State private var dropTargeted = false
    @State private var sheet: NameSheet.Kind?
    @State private var pendingDelete: [Entry] = []
    @State private var opError: String?

    private var storage: DeviceManager.Storage? {
        device.storages.first { $0.id == storageID } ?? device.storages.first
    }

    private var folder: UInt32 { path.last?.id ?? DeviceManager.rootFolder }

    private var selected: [Entry] { entries.filter { selection.contains($0.id) } }

    /// A context-menu action applies to the whole selection if the clicked row is part of it.
    private func targets(_ e: Entry) -> [Entry] { selection.contains(e.id) ? selected : [e] }

    private var busy: Bool { manager.isTransferring || storage == nil }

    private struct LoadKey: Hashable {
        let storage: UInt32?
        let folder: UInt32
        let version: Int  // bumped after transfers
    }

    var body: some View {
        VStack(spacing: 0) {
            DeviceHeader(name: device.name, status: manager.isTransferring ? "Transferring · USB" : "Connected · USB") {
                if let storage {
                    HStack(spacing: 14) {
                        if device.storages.count > 1 {
                            Menu {
                                ForEach(device.storages) { s in Button(s.name) { storageID = s.id; path = [] } }
                            } label: { EngravedLabel(storage.name, color: Theme.text) }
                            .menuStyle(.borderlessButton).fixedSize()
                        }
                        EngravedLabel("\(bytes(storage.free)) free of \(bytes(storage.capacity))")
                    }
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Button { path.removeLast() } label: { Label("Back", systemImage: "chevron.left").labelStyle(.iconOnly) }
                        .buttonStyle(.faceplate)
                        .disabled(path.isEmpty)
                        .keyboardShortcut("[", modifiers: .command)
                    crumb(storage?.name ?? "Storage", current: path.isEmpty) { path = [] }
                    ForEach(Array(path.enumerated()), id: \.element.id) { i, folder in
                        Text("›").font(Theme.sans(15)).foregroundColor(Theme.faint)
                        crumb(folder.name, current: i == path.count - 1) { path.removeSubrange((i + 1)...) }
                    }
                    Spacer(minLength: 12)
                    Button { sheet = .newFolder } label: { Label("New Folder", systemImage: "folder.badge.plus").labelStyle(.iconOnly) }
                        .buttonStyle(.faceplate)
                        .help("New Folder").disabled(busy).keyboardShortcut("n", modifiers: [.command, .shift])
                    Button { pendingDelete = selected } label: { Label("Delete", systemImage: "trash").labelStyle(.iconOnly) }
                        .buttonStyle(.faceplate)
                        .help("Delete").disabled(busy || selection.isEmpty).keyboardShortcut(.delete, modifiers: .command)
                    Button("Download…") { chooseDownload(selected) }
                        .buttonStyle(.faceplate).disabled(busy || selection.isEmpty)
                    Button("Upload…", action: chooseUpload)
                        .buttonStyle(.faceplatePrimary).disabled(busy)
                }

                Table(selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name, comparator: .localizedStandard) { e in
                        HStack(spacing: 8) {
                            Image(systemName: e.isFolder ? "folder" : "music.note").foregroundStyle(.secondary).frame(width: 16)
                            Text(e.name).font(Theme.sans(13.5)).lineLimit(1).truncationMode(.middle)
                        }
                        .rowActions(e, self)
                    }
                    TableColumn("Size", value: \.size) { e in
                        Text(e.isFolder ? "--" : bytes(e.size)).font(Theme.mono(11.5, .regular)).foregroundStyle(.secondary)
                            .rowActions(e, self)
                    }
                    .width(ideal: 90)
                    TableColumn("Kind", value: \.kind) { e in
                        Text(e.kind).font(Theme.sans(13)).foregroundStyle(.secondary).rowActions(e, self)
                    }
                    TableColumn("Date Modified", value: \.modified) { e in
                        Text(e.modified.formatted(date: .abbreviated, time: .shortened)).font(Theme.mono(11.5, .regular))
                            .foregroundStyle(.secondary).rowActions(e, self)
                    }
                } rows: {
                    ForEach(entries.sorted(using: sortOrder)) { e in TableRow(e).itemProvider { dragProvider(e) } }
                }
                .modifier(RowMenu(browser: self))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(dropTargeted ? Theme.amber : Theme.line,
                                                                   lineWidth: dropTargeted ? 2 : 1))
                .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: drop)
                .overlay {
                    if loading {
                        ProgressView().controlSize(.small)
                    } else if let error {
                        HStack(spacing: 10) { LED(color: Theme.err); Text(error).font(Theme.sans(14)) }
                    } else if entries.isEmpty {
                        VStack(spacing: 8) {
                            Text("Empty folder").font(Theme.serif(28)).foregroundColor(Theme.muted)
                            EngravedLabel("Drop files here to upload", color: Theme.faint)
                        }
                    }
                }
                .task(id: LoadKey(storage: storage?.id, folder: folder, version: manager.listingVersion)) { await load() }
                .sheet(item: $sheet) { kind in
                    NameSheet(kind: kind, taken: Set(entries.map(\.name))) { name in
                        guard let storage = storage?.id else { return }
                        switch kind {
                        case .newFolder:
                            manager.createFolder(device: device.id, storage: storage, parent: folder, name: name) { opError = $0 }
                        case .rename(let e):
                            manager.rename(device: device.id, entry: e, to: name) { opError = $0 }
                        }
                    }
                }
                .confirmationDialog(deleteTitle, isPresented: Binding(get: { !pendingDelete.isEmpty },
                                                                      set: { if !$0 { pendingDelete = [] } })) {
                    Button("Delete", role: .destructive) {
                        manager.delete(device: device.id, entries: pendingDelete) { opError = $0 }
                        pendingDelete = []
                    }
                } message: {
                    Text("This deletes them from the device, including everything inside folders. It can't be undone.")
                }
                .alert(opError ?? "", isPresented: Binding(get: { opError != nil }, set: { if !$0 { opError = nil } })) {}

                if let t = manager.transfer { TransferBar(status: t) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    /// Breadcrumb segment: amber ink like the website's links; the current folder is plain text.
    private func crumb(_ title: String, current: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(Theme.sans(14, current ? .semibold : .regular))
            .foregroundColor(current ? Theme.text : Theme.amberInk)
            .lineLimit(1)
    }

    private var deleteTitle: String {
        pendingDelete.count == 1 ? "Delete “\(pendingDelete[0].name)”?" : "Delete \(pendingDelete.count) items?"
    }

    fileprivate func contextMenu(for e: Entry) -> some View { menu(for: Set(targets(e).map(\.id))) }

    /// Right-click menu for the clicked row, or the whole selection if the clicked row is part of it.
    fileprivate func menu(for ids: Set<UInt32>) -> some View {
        let items = entries.filter { ids.contains($0.id) }
        return Group {
            if items.count == 1, items[0].isFolder { Button("Open") { open(items[0]) } }
            Button("Download…") { chooseDownload(items) }
            Button("Rename…") { sheet = .rename(items[0]) }.disabled(items.count != 1)
            Divider()
            Button("Delete…") { pendingDelete = items }
        }
        .disabled(busy || items.isEmpty)
    }

    /// Double-click / Return on a single folder opens it.
    fileprivate func primaryAction(_ ids: Set<UInt32>) {
        if ids.count == 1, let e = entries.first(where: { ids.contains($0.id) }) { open(e) }
    }

    fileprivate func open(_ e: Entry) {
        if e.isFolder { path.append(e) }
    }

    private func chooseDownload(_ files: [Entry]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Download Here"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        manager.download(device: device.id, entries: files, to: dir)
    }

    private func chooseUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = "Upload"
        guard panel.runModal() == .OK, let storage = storage?.id else { return }
        manager.upload(device: device.id, storage: storage, folder: folder, files: panel.urls)
    }

    /// Files dropped from Finder upload into the current folder.
    private func drop(_ providers: [NSItemProvider]) -> Bool {
        guard let storage = storage?.id, !manager.isTransferring else { return false }
        let folder = folder
        var urls: [URL] = []
        let group = DispatchGroup()
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async { url.map { urls.append($0) }; group.leave() }
            }
        }
        group.notify(queue: .main) { manager.upload(device: device.id, storage: storage, folder: folder, files: urls) }
        return true
    }

    /// Dragging a file or folder out to Finder downloads it to a temp folder, which Finder then copies from.
    /// Holding ⌘ when the drag starts makes it a move: the item is deleted from the device, but only after
    /// the whole download succeeded. (Finder only tells us the drag started, so ⌘ has to be down then.)
    // ponytail: temp copies are left for macOS to clean up; delete them after the drop if disk use matters
    private func dragProvider(_ e: Entry) -> NSItemProvider {
        let move = NSEvent.modifierFlags.contains(.command)
        let provider = NSItemProvider()
        provider.suggestedName = e.name
        let type = e.isFolder ? UTType.folder : UTType(filenameExtension: (e.name as NSString).pathExtension) ?? .data
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) {
            [manager, id = device.id] done in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            DispatchQueue.main.async {
                manager.download(device: id, entries: [e], to: dir) { urls, ok in
                    guard ok, let url = urls.first else {
                        return done(nil, false, DeviceManager.MTPError(errorDescription: "Download failed"))
                    }
                    done(url, false, nil)
                    if move { DispatchQueue.main.async { manager.delete(device: id, entries: [e]) { _ in } } }
                }
            }
            return nil
        }
        return provider
    }

    private func load() async {
        guard let storage = storage?.id else { return }
        let folder = folder
        loading = true
        error = nil
        let result = await Task.detached { [manager, id = device.id] in
            Result { try manager.list(device: id, storage: storage, folder: folder) }
        }.value
        guard !Task.isCancelled else { return }  // user already navigated elsewhere
        switch result {
        case .success(let list): entries = list
        case .failure(let err): entries = []; error = err.localizedDescription
        }
        selection = []
        loading = false
    }

    private func bytes(_ n: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }
}

private struct TransferBar: View {
    @EnvironmentObject var manager: DeviceManager
    let status: TransferStatus

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if status.finished {
                let ok = status.errors.isEmpty && !status.cancelled
                LED(color: ok ? Theme.ok : status.cancelled ? Theme.muted : Theme.err)
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary).font(Theme.sans(14, .medium))
                    ForEach(status.errors, id: \.self) { Text($0).font(Theme.mono(11, .regular)).foregroundColor(Theme.muted) }
                }
                Spacer()
                Button("Dismiss") { manager.transfer = nil }.buttonStyle(.faceplate)
            } else {
                LED()
                VStack(alignment: .leading, spacing: 10) {
                    // this file
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            EngravedLabel("\(status.verb) \(status.index + 1) of \(status.count)")
                            Text(status.name).font(Theme.sans(13.5)).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 8)
                            EngravedLabel(percent(status.fraction))
                        }
                        ProgressLine(value: status.fraction, label: "This file")
                    }
                    // the whole batch (a dropped folder), by bytes
                    if status.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                EngravedLabel("Total")
                                Text("\(bytes(copied)) of \(bytes(status.totalBytes))")
                                    .font(Theme.mono(11.5, .regular)).foregroundColor(Theme.muted)
                                Spacer(minLength: 8)
                                EngravedLabel(percent(status.overall))
                            }
                            ProgressLine(value: status.overall, label: "Total", fill: Theme.text)
                        }
                    }
                }
                CancelX { manager.cancelTransfer() }
            }
        }
        .foregroundColor(Theme.text)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private var copied: UInt64 { UInt64(status.overall * Double(status.totalBytes)) }
    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded(.down)))%" }
    private func bytes(_ n: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file) }

    private var summary: String {
        if status.cancelled {
            return status.errors.isEmpty ? "Cancelled. Nothing was kept." : "Cancelled, but some items couldn't be removed"
        }
        if !status.errors.isEmpty { return "Finished with \(status.errors.count) problem\(status.errors.count == 1 ? "" : "s")" }
        let done = status.verb == "Uploading" ? "Uploaded" : "Downloaded"
        return "\(done) \(status.count) file\(status.count == 1 ? "" : "s")"
    }
}

/// Finder-style round ✕ beside the progress bars; cancels the whole transfer.
private struct CancelX: View {
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Label("Cancel transfer", systemImage: "xmark.circle.fill").labelStyle(.iconOnly)
                .font(.system(size: 16))
                .foregroundColor(hover ? Theme.text : Theme.muted)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Cancel transfer")
    }
}

/// Thin progress line: amber for the current file, bone/ink for the batch total.
private struct ProgressLine: View {
    let value: Double
    let label: String
    var fill = Theme.amber
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.line)
            Capsule().fill(fill).scaleEffect(x: max(0.001, min(1, value)), anchor: .leading)
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// Name prompt for New Folder and Rename.
private struct NameSheet: View {
    enum Kind: Identifiable {
        case newFolder
        case rename(DeviceManager.Entry)
        var id: String { if case .rename(let e) = self { return "rename-\(e.id)" }; return "new" }
    }

    let kind: Kind
    let taken: Set<String>
    let save: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var original: String? { if case .rename(let e) = kind { return e.name }; return nil }
    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private var problem: String? {
        if trimmed.contains("/") { return "Names can't contain “/”." }
        if trimmed != original, taken.contains(trimmed) { return "That name is already taken here." }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EngravedLabel(original == nil ? "New folder" : "Rename")
            Text(original.map { "“\($0)”" } ?? "Name the folder").font(Theme.serif(26)).lineLimit(1).truncationMode(.middle)
            TextField("Name", text: $name)
                .textFieldStyle(.plain)
                .font(Theme.sans(15))
                .padding(.horizontal, 10).frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.panel2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(problem == nil ? Theme.line : Theme.err))
                .onSubmit(submit)
            if let problem { Text(problem).font(Theme.sans(13)).foregroundColor(Theme.err) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.faceplate).keyboardShortcut(.cancelAction)
                Button(original == nil ? "Create" : "Rename", action: submit)
                    .buttonStyle(.faceplatePrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || problem != nil)
            }
        }
        .foregroundColor(Theme.text)
        .padding(24)
        .frame(width: 380)
        .background(Theme.bg)
        .onAppear { name = original ?? "untitled folder" }
    }

    private func submit() {
        guard !trimmed.isEmpty, problem == nil else { return }
        if trimmed != original { save(trimmed) }
        dismiss()
    }
}

/// macOS 13+: the table's own row-level double-click and context menu. Nothing sits on the cells, so every
/// click reaches the table and selects (focused, i.e. amber) reliably.
private struct RowMenu: ViewModifier {
    let browser: BrowserView
    func body(content: Content) -> some View {
        if #available(macOS 13, *) {
            content.contextMenu(forSelectionType: UInt32.self) { browser.menu(for: $0) }
                primaryAction: { browser.primaryAction($0) }
        } else {
            content
        }
    }
}

private extension View {
    /// macOS 12 fallback: Table has no row-level primary action or context menu, so they go on each cell.
    /// The double-click is *simultaneous* so the click still reaches the table and selects the row.
    @ViewBuilder func rowActions(_ e: DeviceManager.Entry, _ browser: BrowserView) -> some View {
        if #available(macOS 13, *) {
            self
        } else {
            frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded { browser.open(e) })
                .contextMenu { browser.contextMenu(for: e) }
        }
    }
}
