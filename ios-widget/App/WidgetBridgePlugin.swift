import Foundation
import Capacitor
import WidgetKit

// Hands the widget its summary of jobs through the shared App Group, then asks iPhone to redraw it.
@objc(WidgetBridgePlugin)
public class WidgetBridgePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "WidgetBridgePlugin"
    public let jsName = "WidgetBridge"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "set", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setNotify", returnType: CAPPluginReturnPromise)
    ]

    static let group = "group.com.gmoghul.mumbrainsorted"

    @objc func set(_ call: CAPPluginCall) {
        guard let json = call.getString("json") else {
            call.reject("Missing json")
            return
        }
        UserDefaults(suiteName: WidgetBridgePlugin.group)?.set(json, forKey: "widget")
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }

    // The key that unscrambles shared-change notifications, for the notification extension.
    // Empty clears it (left the family, or notifications switched off).
    @objc func setNotify(_ call: CAPPluginCall) {
        let key = call.getString("key") ?? ""
        let d = UserDefaults(suiteName: WidgetBridgePlugin.group)
        if key.isEmpty { d?.removeObject(forKey: "notifyKey") } else { d?.set(key, forKey: "notifyKey") }
        call.resolve()
    }
}
