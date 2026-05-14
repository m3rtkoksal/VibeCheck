import AVFoundation
import Combine

/// Ses örneği dosyası; kayıt ve ileride API’ye yükleme aynı yolu kullanır.
enum VoiceCharacterSampleFile {
    static let filename = "profileVoiceCharacterSample.wav"

    static var directoryURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var sampleURL: URL {
        directoryURL.appendingPathComponent(filename, isDirectory: false)
    }
}

@MainActor
final class ProfileVoiceSampleRecorder: ObservableObject {
    private let targetDurationSeconds: TimeInterval = 15

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var averagePowerDb: Float = -160
    @Published private(set) var hasSampleOnDisk = false
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var tickTask: Task<Void, Never>?
    private var startInFlight = false

    var secondsRemainingRounded: Int {
        max(0, Int(ceil(targetDurationSeconds - elapsed)))
    }

    var sheetCountdownLabel: String {
        let capped = Int(ceil(targetDurationSeconds))
        guard isRecording else {
            return String(format: "%02d:%02d", capped / 60, capped % 60)
        }
        let r = secondsRemainingRounded
        return String(format: "%02d:%02d", r / 60, r % 60)
    }

    func refreshSavedState() {
        hasSampleOnDisk = FileManager.default.fileExists(atPath: VoiceCharacterSampleFile.sampleURL.path)
    }

    /// Kayıt başlat; izin/red ve teknik hatada `false`.
    func beginRecordingFromSheet() async -> Bool {
        if isRecording { return true }
        guard !startInFlight else { return false }
        startInFlight = true
        defer { startInFlight = false }
        return await startRecording()
    }

    func stopRecordingSaving() {
        finalizeRecording(stopReason: .user)
    }

    private enum StopReason {
        case user
        case timeLimit
    }

    @discardableResult
    private func startRecording() async -> Bool {
        errorMessage = nil
        guard await requestMicrophonePermission() else {
            errorMessage = "Mikrofon izni kapalı. Ayarlar'dan izin verip tekrar dene."
            return false
        }

        tickTask?.cancel()
        tickTask = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = VoiceCharacterSampleFile.sampleURL
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()

            guard recorder?.record() == true else {
                throw NSError(
                    domain: "ProfileVoiceSampleRecorder",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Ses kaydı başlatılamadı."]
                )
            }

            elapsed = 0
            averagePowerDb = -160
            isRecording = true
            refreshSavedState()

            tickTask = Task { [weak self] in
                await self?.runRecordingClock()
            }
            return true
        } catch {
            errorMessage = "Kayıt başlatılamadı: \(error.localizedDescription)"
            cleanupAfterFailure()
            return false
        }
    }

    private func runRecordingClock() async {
        let start = Date()
        while !Task.isCancelled {
            let now = Date().timeIntervalSince(start)
            await MainActor.run {
                self.elapsed = min(now, self.targetDurationSeconds)
                if let r = self.recorder, r.isRecording {
                    r.updateMeters()
                    self.averagePowerDb = r.averagePower(forChannel: 0)
                }
            }
            if now >= targetDurationSeconds {
                await MainActor.run {
                    self.finalizeRecording(stopReason: .timeLimit)
                }
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func finalizeRecording(stopReason: StopReason) {
        tickTask?.cancel()
        tickTask = nil

        guard isRecording || recorder != nil else { return }

        recorder?.stop()
        recorder = nil
        isRecording = false
        averagePowerDb = -160

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}

        refreshSavedState()

        if stopReason == .timeLimit, !hasSampleOnDisk {
            errorMessage = "Kayıt dosyası oluşturulamadı. Tekrar dene."
        }
    }

    private func cleanupAfterFailure() {
        tickTask?.cancel()
        tickTask = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        averagePowerDb = -160
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
