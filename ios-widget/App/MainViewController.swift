import UIKit
import Capacitor

// Capacitor's screen, plus the app's own small plugins: the widget bridge and the iCloud backup.
class MainViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(WidgetBridgePlugin())
        bridge?.registerPluginInstance(ICloudBackupPlugin())
    }
}
