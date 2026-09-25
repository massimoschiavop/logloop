import Foundation

extension Int {
    /// I secondi come minuti e secondi, es. "1:30".
    var formattedDuration: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
    }
}
