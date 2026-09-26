import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var manager: DeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if manager.devices.isEmpty {
                Text("Connect an MTP device over USB.").foregroundColor(.secondary)
                Spacer()
            } else {
                if manager.devices.count > 1 {
                    Picker("Device", selection: $manager.activeID) {
                        ForEach(manager.devices) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                if let device = manager.active {
                    if let error = device.error {
                        Text(device.name).font(.title2)
                        Text(error).foregroundColor(.red)
                        Button("Retry") { manager.scheduleRescan(after: 0) }
                        Spacer()
                    } else {
                        BrowserView(device: device).id(device.id)  // fresh browser state per device
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 400)
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
        HStack {
            Text(device.name).font(.title2)
            Spacer()
            if device.storages.count > 1 {
                Picker("Storage", selection: Binding(get: { storage?.id }, set: { storageID = $0; path = [] })) {
                    ForEach(device.storages) { Text($0.name).tag(Optional($0.id)) }
                }
                .fixedSize()
            }
            if let storage {
                Text("\(bytes(storage.free)) free of \(bytes(storage.capacity))").foregroundColor(.secondary)
            }
        }

        HStack(spacing: 4) {
            Button { path.removeLast() } label: { Image(systemName: "chevron.left") }
                .disabled(path.isEmpty)
                .keyboardShortcut("[", modifiers: .command)
            Button(storage?.name ?? "Storage") { path = [] }.buttonStyle(.link)
            ForEach(Array(path.enumerated()), id: \.element.id) { i, folder in
                Image(systemName: "chevron.right").foregroundColor(.secondary).imageScale(.small)
                Button(folder.name) { path.removeSubrange((i + 1)...) }.buttonStyle(.link)
            }
            Spacer()
            Button { sheet = .newFolder } label: { Image(systemName: "folder.badge.plus") }
                .help("New Folder").disabled(busy).keyboardShortcut("n", modifiers: [.command, .shift])
            Button { pendingDelete = selected } label: { Image(systemName: "trash") }
                .help("Delete").disabled(busy || selection.isEmpty).keyboardShortcut(.delete, modifiers: .command)
            Button("Download…") { chooseDownload(selected) }.disabled(busy || selection.isEmpty)
            Button("Upload…", action: chooseUpload).disabled(busy)
        }

        Table(entries.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name, comparator: .localizedStandard) { e in
                Label(e.name, systemImage: e.isFolder ? "folder" : "doc").rowActions(e, self).onDrag { dragProvider(e) }
            }
            TableColumn("Size", value: \.size) { e in
                Text(e.isFolder ? "--" : bytes(e.size)).rowActions(e, self)
            }
            .width(ideal: 80)
            TableColumn("Kind", value: \.kind) { e in Text(e.kind).rowActions(e, self) }
            TableColumn("Date Modified", value: \.modified) { e in
                Text(e.modified.formatted(date: .abbreviated, time: .shortened)).rowActions(e, self)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: drop)
        .border(dropTargeted ? Color.accentColor : .clear, width: 2)
        .overlay {
            if loading {
                ProgressView()
            } else if let error {
                Text(error).foregroundColor(.red)
            } else if entries.isEmpty {
                Text("Empty folder").foregroundColor(.secondary)
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

    private var deleteTitle: String {
        pendingDelete.count == 1 ? "Delete “\(pendingDelete[0].name)”?" : "Delete \(pendingDelete.count) items?"
    }

    fileprivate func contextMenu(for e: Entry) -> some View {
        Group {
            if e.isFolder { Button("Open") { open(e) } }
            Button("Download…") { chooseDownload(targets(e)) }
            Button("Rename…") { sheet = .rename(e) }.disabled(targets(e).count > 1)
            Divider()
            Button("Delete…") { pendingDelete = targets(e) }
        }
        .disabled(busy)
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
        HStack(alignment: .top) {
            if status.finished {
                let ok = status.errors.isEmpty && !status.cancelled
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(ok ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary)
                    ForEach(status.errors, id: \.self) { Text($0).font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
                Button("Dismiss") { manager.transfer = nil }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(status.verb) \(status.index + 1) of \(status.count): \(status.name)")
                        .lineLimit(1).truncationMode(.middle)
                    ProgressView(value: status.fraction)
                }
                Button("Cancel") { manager.cancelTransfer() }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var summary: String {
        if status.cancelled { return "Cancelled" }
        if !status.errors.isEmpty { return "Finished with \(status.errors.count) problem\(status.errors.count == 1 ? "" : "s")" }
        let done = status.verb == "Uploading" ? "Uploaded" : "Downloaded"
        return "\(done) \(status.count) file\(status.count == 1 ? "" : "s")"
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
        VStack(alignment: .leading, spacing: 12) {
            Text(original == nil ? "New Folder" : "Rename “\(original!)”").font(.headline)
            TextField("Name", text: $name).onSubmit(submit)
            if let problem { Text(problem).font(.caption).foregroundColor(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(original == nil ? "Create" : "Rename", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || problem != nil)
            }
        }
        .padding()
        .frame(width: 340)
        .onAppear { name = original ?? "untitled folder" }
    }

    private func submit() {
        guard !trimmed.isEmpty, problem == nil else { return }
        if trimmed != original { save(trimmed) }
        dismiss()
    }
}

private extension View {
    /// Double-click to open and a context menu, anywhere in the cell.
    /// macOS 12 Table has no row-level primary action or context menu (those are macOS 13+).
    func rowActions(_ e: DeviceManager.Entry, _ browser: BrowserView) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { browser.open(e) }
            .contextMenu { browser.contextMenu(for: e) }
    }
}
