import Foundation
import Capacitor

// Keeps a copy of the user's own jobs in their own iCloud (Apple's key-value storage for the app),
// so a lost or new phone can bring them back. Nothing here goes to the app's Firebase.
// Each phone or iPad writes to its own slot: "bk.<slot>" is the packed backup, "meta.<slot>" says when and how many jobs.
@objc(ICloudBackupPlugin)
public class ICloudBackupPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ICloudBackupPlugin"
    public let jsName = "ICloudBackup"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "list", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "save", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "read", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "remove", returnType: CAPPluginReturnPromise)
    ]

    private let store = NSUbiquitousKeyValueStore.default
    // iCloud allows 1 MB for the whole app; two slots of this size fit with room to spare
    private static let maxBytes = 450_000

    override public func load() {
        NotificationCenter.default.addObserver(self, selector: #selector(changed(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
        store.synchronize()
    }

    // iCloud has delivered something new (for example, just after a fresh install)
    @objc private func changed(_ note: Notification) {
        notifyListeners("changed", data: [:])
    }

    private var signedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }

    @objc func list(_ call: CAPPluginCall) {
        store.synchronize()
        var out: [[String: String]] = []
        for (key, value) in store.dictionaryRepresentation where key.hasPrefix("meta.") {
            let slot = String(key.dropFirst(5))
            if let meta = value as? String, store.data(forKey: "bk." + slot) != nil {
                out.append(["slot": slot, "meta": meta])
            }
        }
        call.resolve(["available": signedIn, "backups": out])
    }

    @objc func save(_ call: CAPPluginCall) {
        guard signedIn else { call.reject("Not signed in to iCloud", "noaccount"); return }
        guard let slot = call.getString("slot"), !slot.isEmpty,
              let json = call.getString("json"), let meta = call.getString("meta") else {
            call.reject("Missing slot, json or meta"); return
        }
        guard let packed = try? (Data(json.utf8) as NSData).compressed(using: .zlib) as Data else {
            call.reject("Couldn't pack the backup"); return
        }
        if packed.count > ICloudBackupPlugin.maxBytes { call.reject("Backup too big for iCloud", "toobig"); return }
        // keep this device's backup and one other (the newest, chosen by the app); older ones go, to stay inside iCloud's limit
        let keep = call.getString("keep") ?? ""
        for key in store.dictionaryRepresentation.keys where key.hasPrefix("meta.") {
            let other = String(key.dropFirst(5))
            if other != slot && other != keep {
                store.removeObject(forKey: "meta." + other)
                store.removeObject(forKey: "bk." + other)
            }
        }
        store.set(packed, forKey: "bk." + slot)
        store.set(meta, forKey: "meta." + slot)
        store.synchronize()
        call.resolve(["bytes": packed.count])
    }

    @objc func read(_ call: CAPPluginCall) {
        guard let slot = call.getString("slot"), let packed = store.data(forKey: "bk." + slot),
              let raw = try? (packed as NSData).decompressed(using: .zlib) as Data,
              let json = String(data: raw, encoding: .utf8) else {
            call.reject("No backup found", "missing"); return
        }
        call.resolve(["json": json])
    }

    @objc func remove(_ call: CAPPluginCall) {
        guard let slot = call.getString("slot"), !slot.isEmpty else { call.reject("Missing slot"); return }
        store.removeObject(forKey: "meta." + slot)
        store.removeObject(forKey: "bk." + slot)
        store.synchronize()
        call.resolve()
    }
}
