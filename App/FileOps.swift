import Foundation

/// Create, rename, and delete on the device. Each runs on the mtp queue and calls `completion` on main
/// with an error message or nil, after bumping `listingVersion` so the browser reloads.
extension DeviceManager {
    func createFolder(device: String, storage: UInt32, parent: UInt32, name: String,
                      completion: @escaping (String?) -> Void) {
        perform(device: device, completion: completion) { h in
            self.makeFolder(h, name: name, parent: parent, storage: storage) == 0
                ? "Couldn't create “\(name)” on the device." : nil
        }
    }

    func rename(device: String, entry: Entry, to name: String, completion: @escaping (String?) -> Void) {
        perform(device: device, completion: completion) { h in
            let copy = strdup(name)  // libmtp takes a mutable char* and may rewrite it
            defer { free(copy) }
            return LIBMTP_Set_Object_Filename(h, entry.id, copy) == 0 ? nil : "Couldn't rename “\(entry.name)”."
        }
    }

    /// Deletes files and folders, folders depth-first: not every MTP device deletes non-empty folders.
    /// Stops at the first failure.
    func delete(device: String, entries: [Entry], completion: @escaping (String?) -> Void) {
        perform(device: device, completion: completion) { h in
            for e in entries {
                if let err = self.deleteTree(h, e) { return err }
            }
            return nil
        }
        scheduleRescan(after: 0)  // refresh free space
    }

    /// mtp queue only. Returns the new folder's id, or 0 on failure.
    func makeFolder(_ h: Handle, name: String, parent: UInt32, storage: UInt32) -> UInt32 {
        let copy = strdup(name)  // libmtp takes a mutable char* and may rewrite it
        defer { free(copy) }
        let id = LIBMTP_Create_Folder(h, copy, parent, storage)
        if id == 0 { LIBMTP_Clear_Errorstack(h) }
        return id
    }

    private func deleteTree(_ h: Handle, _ e: Entry) -> String? {
        if e.isFolder {
            guard let children = try? listFolder(h, storage: e.storage, folder: e.id) else {
                return "Couldn't read the folder “\(e.name)”."
            }
            for child in children {
                if let err = deleteTree(h, child) { return err }
            }
        }
        guard LIBMTP_Delete_Object(h, e.id) == 0 else {
            LIBMTP_Clear_Errorstack(h)
            return "Couldn't delete “\(e.name)”."
        }
        return nil
    }

    private func perform(device: String, completion: @escaping (String?) -> Void, _ work: @escaping (Handle) -> String?) {
        mtp.async {
            let err = self.handles[device].map(work) ?? "The device was disconnected."
            DispatchQueue.main.async {
                self.listingVersion += 1
                completion(err)
            }
        }
    }
}
