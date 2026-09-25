import UIKit

extension Notification.Name {
    /// Il telefono è stato scosso.
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// Lo scuotimento arriva alla finestra anche senza un campo di testo attivo, a differenza
/// dell'annulla di sistema: lo si inoltra all'app, che mostra il suo.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
