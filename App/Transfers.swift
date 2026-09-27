import Foundation

struct TransferStatus {
    let verb: String  // "Downloading" / "Uploading"
    var count = 0     // files, known once folders have been expanded
    var index = 0
    var name = ""
    var fraction = 0.0         // of the current file
    var totalBytes: UInt64 = 0 // whole batch, known with `count`
    var doneBytes: UInt64 = 0  // files already finished (or failed)
    var currentBytes: UInt64 = 0
    var finished = false
    var cancelled = false
    var errors: [String] = []

    /// Whole-batch progress by bytes, so a 300 MB FLAC weighs more than a 3 MB MP3.
    var overall: Double {
        totalBytes == 0 ? 0 : min(1, (Double(doneBytes) + fraction * Double(currentBytes)) / Double(totalBytes))
    }
}

/// File and folder copies in both directions. One batch at a time: folders are expanded into a flat
/// file list first, then files are copied one by one on the mtp queue.
/// libmtp streams in chunks, so file size doesn't affect memory use.
extension DeviceManager {
    typealias Handle = UnsafeMutablePointer<LIBMTP_mtpdevice_t>

    /// One file to copy. `run` returns an error message, or nil on success or cancel.
    private struct Job {
        let name: String
        let size: UInt64  // for the overall progress bar
        let run: (Handle) -> String?
    }

    var isTransferring: Bool { transfer.map { !$0.finished } ?? false }

    func cancelTransfer() {
        cancelLock.withLock { cancelRequested = true }
    }

    /// Downloads files and folders into `dir`. `completion` runs on the mtp queue with the top-level items
    /// written, and whether everything succeeded.
    func download(device: String, entries: [Entry], to dir: URL, completion: (([URL], Bool) -> Void)? = nil) {
        var written: [URL] = []
        runBatch(verb: "Downloading", device: device, plan: { h in
            var jobs: [Job] = []
            var errors: [String] = []
            func add(_ e: Entry, into dir: URL, topLevel: Bool) {
                guard e.isFolder else {
                    jobs.append(Job(name: e.name, size: e.size) { h in
                        switch self.downloadOne(h, e, to: dir) {
                        case .success(let url): if topLevel { written.append(url) }; return nil
                        case .failure(let err): return err.errorDescription
                        }
                    })
                    return
                }
                let sub = topLevel ? Self.uniqueURL(dir.appendingPathComponent(e.name)) : dir.appendingPathComponent(e.name)
                do {
                    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                    if topLevel { written.append(sub) }
                    for child in try self.listFolder(h, storage: e.storage, folder: e.id) {
                        add(child, into: sub, topLevel: false)
                    }
                } catch {
                    errors.append("\(e.name): \(error.localizedDescription)")
                }
            }
            entries.forEach { add($0, into: dir, topLevel: true) }
            return (jobs, errors)
        }, undo: { _ in
            // Cancelled: remove every top-level file and folder this batch created (folders take their contents).
            defer { written.removeAll() }
            return written.compactMap { url in
                (try? FileManager.default.removeItem(at: url)) == nil ? "\(url.lastPathComponent): couldn't remove it from your Mac" : nil
            }
        }, done: { ok in
            completion?(written, ok)
        })
    }

    /// Uploads local files and folders into `folder` on the device. Hidden files (.DS_Store etc.) are skipped.
    func upload(device: String, storage: UInt32, folder: UInt32, files: [URL], completion: (() -> Void)? = nil) {
        var added = Set<String>()  // top-level names this batch creates in `folder`
        runBatch(verb: "Uploading", device: device, plan: { h in
            var jobs: [Job] = []
            var errors: [String] = []
            let existing = Set(((try? self.listFolder(h, storage: storage, folder: folder)) ?? []).map(\.name))
            func add(_ url: URL, into parent: UInt32, topLevel: Bool) {
                let name = url.lastPathComponent
                if topLevel, existing.contains(name) {
                    return errors.append("\(name): something with this name already exists here")
                }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                guard values?.isDirectory == true else {
                    let size = UInt64(values?.fileSize ?? 0)
                    return jobs.append(Job(name: name, size: size) { h in self.uploadOne(h, url, storage: storage, folder: parent) })
                }
                let id = self.makeFolder(h, name: name, parent: parent, storage: storage)
                guard id != 0 else { return errors.append("\(name): couldn't create the folder on the device") }
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles)) ?? []
                for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    add(child, into: id, topLevel: false)
                }
            }
            files.forEach { add($0, into: folder, topLevel: true) }
            added = Set(files.map(\.lastPathComponent)).subtracting(existing)
            return (jobs, errors)
        }, undo: { h in
            // Cancelled: delete what this batch added to the device. Names that already existed were refused
            // in planning, so nothing that was there before is touched.
            guard let h, !added.isEmpty else { return [] }
            guard let now = try? self.listFolder(h, storage: storage, folder: folder) else {
                return ["Couldn't read the device to remove the partial upload."]
            }
            return now.filter { added.contains($0.name) }.compactMap { self.deleteTree(h, $0) }
        }, done: { _ in
            completion?()
        })
    }

    /// `undo` runs on the mtp queue only if the batch was cancelled, and returns what it couldn't undo.
    private func runBatch(verb: String, device: String, plan: @escaping (Handle) -> ([Job], [String]),
                          undo: @escaping (Handle?) -> [String], done: @escaping (_ ok: Bool) -> Void) {
        guard !isTransferring else { return done(false) }  // callers (e.g. drag-out) always get an answer
        cancelLock.withLock { cancelRequested = false }
        transfer = TransferStatus(verb: verb)
        mtp.async {
            var jobs: [Job] = []
            var errors: [String] = []
            if let h = self.handles[device] {
                (jobs, errors) = plan(h)
            } else {
                errors.append("The device was disconnected.")
            }
            let total = jobs.reduce(0) { $0 + $1.size }
            DispatchQueue.main.async { self.transfer?.count = jobs.count; self.transfer?.totalBytes = total }
            var copied: UInt64 = 0
            for (i, job) in jobs.enumerated() {
                if self.isCancelled { break }
                DispatchQueue.main.async { [copied] in
                    self.transfer?.index = i; self.transfer?.name = job.name; self.transfer?.fraction = 0
                    self.transfer?.currentBytes = job.size; self.transfer?.doneBytes = copied
                }
                guard let h = self.handles[device] else {
                    errors.append("The device was disconnected.")
                    break
                }
                if let err = job.run(h) { errors.append(err) }
                copied += job.size
            }
            DispatchQueue.main.async { [copied] in self.transfer?.doneBytes = copied; self.transfer?.fraction = 0 }
            let cancelled = self.isCancelled
            if cancelled {  // cancel means the whole batch, not just the file in flight
                DispatchQueue.main.async { self.transfer?.name = "Removing what was already copied…" }
                errors = undo(self.handles[device])
            }
            done(errors.isEmpty && !cancelled)
            DispatchQueue.main.async {
                self.transfer?.finished = true
                self.transfer?.cancelled = cancelled
                self.transfer?.errors = errors
                self.listingVersion += 1
                self.scheduleRescan(after: 0)  // refresh free space
            }
        }
    }

    private var isCancelled: Bool { cancelLock.withLock { cancelRequested } }

    private var progressContext: UnsafeRawPointer { UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()) }

    /// libmtp progress callback; returning non-zero cancels the transfer.
    private static let progress: LIBMTP_progressfunc_t = { sent, total, ctx in
        let m = Unmanaged<DeviceManager>.fromOpaque(ctx!).takeUnretainedValue()
        let f = total > 0 ? Double(sent) / Double(total) : 1
        if f - m.lastReportedFraction >= 0.005 || sent == total {  // don't flood the main queue
            m.lastReportedFraction = f
            DispatchQueue.main.async { m.transfer?.fraction = f }
        }
        return m.isCancelled ? 1 : 0
    }

    /// Writes to a hidden temp file next to the destination and only renames it into place once complete,
    /// so a cancel, error, or unplug never leaves a truncated file that looks real.
    private func downloadOne(_ h: Handle, _ e: Entry, to dir: URL) -> Result<URL, MTPError> {
        let fm = FileManager.default
        let tmp = dir.appendingPathComponent(".\(e.name).mtpdownload")
        try? fm.removeItem(at: tmp)
        lastReportedFraction = 0
        LIBMTP_Clear_Errorstack(h)
        let ret = LIBMTP_Get_File_To_File(h, e.id, tmp.path, Self.progress, progressContext)
        let size = (try? tmp.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init)
        guard ret == 0, size == e.size else {
            try? fm.removeItem(at: tmp)
            LIBMTP_Clear_Errorstack(h)
            if isCancelled { return .failure(MTPError(errorDescription: nil)) }
            return .failure(MTPError(errorDescription: ret == 0
                ? "\(e.name): incomplete download (\(size ?? 0) of \(e.size) bytes), discarded"
                : "\(e.name): download failed"))
        }
        do {
            let dest = Self.uniqueURL(dir.appendingPathComponent(e.name))
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tmp.path)  // libmtp creates 0750
            try fm.moveItem(at: tmp, to: dest)
            return .success(dest)
        } catch {
            try? fm.removeItem(at: tmp)
            return .failure(MTPError(errorDescription: "\(e.name): \(error.localizedDescription)"))
        }
    }

    /// On failure, deletes whatever partial object the device created.
    private func uploadOne(_ h: Handle, _ url: URL, storage: UInt32, folder: UInt32) -> String? {
        let name = url.lastPathComponent
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return "\(name): couldn't read the file"
        }

        guard let f = LIBMTP_new_file_t() else { return "\(name): out of memory" }
        defer { LIBMTP_destroy_file_t(f) }  // also frees filename
        f.pointee.filename = strdup(name)
        f.pointee.filesize = UInt64(size)
        f.pointee.filetype = LIBMTP_FILETYPE_UNKNOWN  // Android identifies files by extension
        f.pointee.parent_id = folder
        f.pointee.storage_id = storage

        lastReportedFraction = 0
        LIBMTP_Clear_Errorstack(h)
        guard LIBMTP_Send_File_From_File(h, url.path, f, Self.progress, progressContext) != 0 else { return nil }
        LIBMTP_Clear_Errorstack(h)
        // item_id is set once the device has accepted the object info, i.e. a (partial) object may exist.
        // Android removes it itself on cancel, so only complain if it's actually still there.
        if f.pointee.item_id != 0, LIBMTP_Delete_Object(h, f.pointee.item_id) != 0 {
            LIBMTP_Clear_Errorstack(h)
            if let leftover = LIBMTP_Get_Filemetadata(h, f.pointee.item_id) {
                LIBMTP_destroy_file_t(leftover)
                return "\(name): upload stopped and a partial copy remains on the device. Delete it before using it."
            }
            LIBMTP_Clear_Errorstack(h)
        }
        return isCancelled ? nil : "\(name): upload failed"
    }

    /// "Song.flac" -> "Song 2.flac" if taken, like Finder.
    static func uniqueURL(_ url: URL) -> URL {
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var candidate = url
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }
}
