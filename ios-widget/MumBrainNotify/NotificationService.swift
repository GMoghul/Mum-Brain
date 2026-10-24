import UserNotifications
import CryptoKit

// Shared-list notifications arrive scrambled, so the server never sees what changed.
// This runs on the phone just before the notification shows: it unscrambles the message with the
// family key (handed over by the app through the App Group) and fills in the job, who changed it and how.
// If anything goes wrong, the plain "something changed" text from the server is shown instead.
class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    private var sent = false

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        handler = contentHandler
        let c = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        content = c
        if let note = NotificationService.unscramble(c.userInfo) {
            if let t = note["t"] as? String, !t.isEmpty { c.title = t }
            if let s = note["s"] as? String { c.subtitle = s }
            if let b = note["b"] as? String, !b.isEmpty { c.body = b }
        }
        finish()
    }

    override func serviceExtensionTimeWillExpire() { finish() }

    private func finish() {
        guard !sent, let h = handler, let c = content else { return }
        sent = true
        h(c)
    }

    static func unscramble(_ info: [AnyHashable: Any]) -> [String: Any]? {
        guard let mb = info["mb"] as? [String: Any],
              let ivS = mb["iv"] as? String, let ctS = mb["ct"] as? String,
              let keyS = UserDefaults(suiteName: "group.com.gmoghul.mumbrainsorted")?.string(forKey: "notifyKey"),
              let key = Data(base64Encoded: keyS), key.count == 32,
              let iv = Data(base64Encoded: ivS), let ct = Data(base64Encoded: ctS), ct.count > 16
        else { return nil }
        do {
            // Web Crypto puts the 16-byte check tag on the end of the scrambled text
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv),
                                            ciphertext: ct.prefix(ct.count - 16),
                                            tag: ct.suffix(16))
            let plain = try AES.GCM.open(box, using: SymmetricKey(data: key),
                                         authenticating: Data("mb-note".utf8))
            return try JSONSerialization.jsonObject(with: plain) as? [String: Any]
        } catch {
            return nil
        }
    }
}
