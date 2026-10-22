import UIKit
import Capacitor

// Capacitor's screen, plus the app's own small plugin for the widget.
class MainViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(WidgetBridgePlugin())
    }
}
