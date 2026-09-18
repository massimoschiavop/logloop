import UIKit

@MainActor
enum IdleTimerGuard {
    static func disableSleep(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
