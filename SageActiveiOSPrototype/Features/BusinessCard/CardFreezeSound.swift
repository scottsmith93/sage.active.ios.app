import AVFoundation

/// A short, locally synthesized wind cue. Ambient playback respects Silent Mode.
@MainActor
final class CardFreezeSound {
    private var player: AVAudioPlayer?
    private var ownsSession = false

    func play() {
        stop()
        guard let url = Bundle.main.url(forResource: "card-freeze-wind", withExtension: "wav") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
            ownsSession = true
            let cue = try AVAudioPlayer(contentsOf: url)
            cue.volume = 0.3
            cue.prepareToPlay()
            player = cue
            cue.play()
        } catch {
            stop()
        }
    }

    func stop() {
        guard ownsSession else { return }
        player?.stop()
        player = nil
        ownsSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
