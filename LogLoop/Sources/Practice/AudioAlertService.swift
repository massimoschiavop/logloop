import AVFoundation
import AudioToolbox
import UIKit

/// Tiene viva la sessione in background e suona l'avviso di fine step.
///
/// Il loop di silenzio gira per tutta la durata della sessione, pausa inclusa: iOS
/// sospende l'app appena l'output audio cessa, e la pausa è proprio il momento in cui
/// è più probabile che l'utente blocchi lo schermo.
@MainActor
final class AudioAlertService {
    private var keepAlivePlayer: AVAudioPlayer?
    private var alertPlayer: AVAudioPlayer?
    private let haptics = UINotificationFeedbackGenerator()
    private var isActive = false

    init() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        configureSession()
        buildPlayers()
        keepAlivePlayer?.play()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        alertPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func prepareHaptics() {
        haptics.prepare()
    }

    func fireAlert() {
        alertPlayer?.currentTime = 0
        alertPlayer?.play()

        if UIApplication.shared.applicationState == .active {
            haptics.notificationOccurred(.success)
            haptics.prepare()
        } else {
            // UIFeedbackGenerator e Core Haptics sono no-op fuori dal foreground:
            // AudioToolbox raggiunge comunque il motore di vibrazione.
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // .playback ignora l'interruttore fisico silenzioso: è il motivo per cui l'avviso è affidabile.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func buildPlayers() {
        if let url = Bundle.main.url(forResource: "silence", withExtension: "caf") {
            keepAlivePlayer = try? AVAudioPlayer(contentsOf: url)
            keepAlivePlayer?.numberOfLoops = -1
            keepAlivePlayer?.volume = 0.01
            keepAlivePlayer?.prepareToPlay()
        }
        if let url = Bundle.main.url(forResource: "alert", withExtension: "caf") {
            alertPlayer = try? AVAudioPlayer(contentsOf: url)
            alertPlayer?.volume = 1.0
            alertPlayer?.prepareToPlay()
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            keepAlivePlayer?.pause()
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume), isActive {
                configureSession()
                keepAlivePlayer?.play()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard
            isActive,
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
        else { return }
        // Staccare le cuffie ferma la riproduzione: senza riavvio la sessione muore in silenzio.
        keepAlivePlayer?.play()
    }

    @objc private func handleMediaServicesReset() {
        guard isActive else { return }
        configureSession()
        buildPlayers()
        keepAlivePlayer?.play()
    }
}
