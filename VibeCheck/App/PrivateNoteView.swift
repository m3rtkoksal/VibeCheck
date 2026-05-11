import AVFoundation
import Speech
import SwiftUI
import UIKit

struct PrivateNoteView: View {
    @Binding var note: String
    @State private var draft: String = ""
    @FocusState private var isEditorFocused: Bool
    @StateObject private var speech = NoteSpeechTranscriber()
    @StateObject private var discoverabilityVM = SettingsDetailViewModel()
    @State private var showIdeaPicker = false
    @State private var promptCopied = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let maxLength = 10000

    var body: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    progressHeader

                    Text("AI karakter özetini buraya yapıştır.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 8)

                    Text(
                        "Aşağıdaki promptu kopyalayıp ChatGPT'ye gönder. "
                            + "Gelen karakter analizini bu alana yapıştır."
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                    promptCard

                    editorCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            HarmonyPanelChrome.toolbarBackGlass(
                                diameter: 36,
                                colorScheme: colorScheme,
                                reduceTransparency: reduceTransparency
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Geri")
            }
            ToolbarItem(placement: .principal) {
                noteToolbarTitle
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                note = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                triggerDiscoverabilitySync()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("Kaydet")
                        .font(.headline)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
            }
            .buttonStyle(.plain)
            .disabled(
                note.trimmingCharacters(in: .whitespacesAndNewlines)
                    == draft.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            .opacity(
                note.trimmingCharacters(in: .whitespacesAndNewlines)
                    == draft.trimmingCharacters(in: .whitespacesAndNewlines) ? 0.6 : 1.0
            )
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            draft = note
        }
        .onChange(of: draft) { _, newValue in
            if newValue.last == "\n" {
                draft = String(newValue.dropLast())
                isEditorFocused = false
                return
            }
            if newValue.count > maxLength {
                draft = String(newValue.prefix(maxLength))
            }
        }
        .onChange(of: speech.transcribedText) { _, newValue in
            guard !newValue.isEmpty else { return }
            draft = String(newValue.prefix(maxLength))
        }
        .confirmationDialog("Fikir Yardımı", isPresented: $showIdeaPicker, titleVisibility: .visible) {
            ForEach(Array(noteIdeas.enumerated()), id: \.offset) { _, idea in
                Button(idea.title) {
                    applyIdea(idea.seed)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Yazmaya başlamak için bir şablon seç.")
        }
        .alert("Sesli Yazma", isPresented: .constant(speech.errorMessage != nil)) {
            Button("Tamam") {
                speech.errorMessage = nil
            }
        } message: {
            Text(speech.errorMessage ?? "")
        }
    }

    private var noteToolbarTitle: some View {
        let dark = colorScheme == .dark
        return Text("VibeCheck")
            .font(.system(size: 20, weight: .heavy, design: .default))
            .tracking(-0.6)
            .foregroundStyle(Color(hex: 0xE51245))
            .shadow(color: dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22), radius: 0, x: 0, y: 1)
            .shadow(color: dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08), radius: 2, x: 0, y: 0)
            .shadow(color: dark ? Color.white.opacity(0.12) : Color.clear, radius: 1, x: 0, y: -0.5)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Soru \(totalQuestions) / \(totalQuestions) Son Soru")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    Capsule()
                        .fill(Color(hex: 0xFF2D55))
                        .frame(width: geo.size.width)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 2)
        }
        .padding(14)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 16, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
        )
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hazır Prompt")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Promptu kopyala, dışarıda çalıştır, cevabı aşağıya yapıştır.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                copyPromptTemplate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                    Text(promptCopied ? "Kopyalandı" : "Promptu Kopyala")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: 0xFF2D55))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    HarmonyPanelChrome.secondaryTintedButtonBackground(
                        cornerRadius: 12,
                        colorScheme: colorScheme
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 18, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 11, x: 0, y: 5)
        )
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $draft)
                .focused($isEditorFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.system(size: 16))
                .frame(minHeight: 180, maxHeight: .infinity)

            HStack(spacing: 12) {
                Button {
                    isEditorFocused = false
                    speech.toggleRecording(currentText: draft, maxLength: maxLength)
                } label: {
                    Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(speech.isRecording ? Color(hex: 0xFF2D55) : .secondary)
                        .frame(width: 42, height: 42)
                        .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 42, colorScheme: colorScheme))
                }
                .buttonStyle(.plain)

                Button {
                    isEditorFocused = false
                    showIdeaPicker = true
                } label: {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 42)
                        .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 42, colorScheme: colorScheme))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(draft.count) / \(maxLength)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 18, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 11, x: 0, y: 5)
        )
    }

    private var totalQuestions: Int {
        ProfileCategory.allCases.count + 1
    }

    private var noteIdeas: [(title: String, seed: String)] {
        [
            (
                "Günlük rutinim",
                "Genelde günüm şu şekilde geçer: Sabah ..., gün içinde ..., akşam ise ..."
            ),
            (
                "İlişkide beklentim",
                "İlişkide benim için en önemli şey ... Çünkü ..."
            ),
            (
                "Beni motive eden şeyler",
                "Beni en çok motive eden şeyler ... Özellikle ... olduğunda enerjim artar."
            ),
            (
                "Tartışma anında tavrım",
                "Bir sorun olduğunda önce ... yaparım. Sonra ... konuşmayı tercih ederim."
            ),
            (
                "Boş zaman tercihim",
                "Boş zamanımda genelde ... yapmayı severim. Bu bana ... hissettirir."
            ),
        ]
    }

    private var promptTemplate: String {
        """
        Beni bir ilişki/karakter danışmanı gibi analiz et.
        Türkçe yaz, net ama yargısız ol.

        Çıktı formatı:
        1) Kısa özet (3-4 cümle)
        2) Güçlü yönlerim (5 madde)
        3) Zorlandığım alanlar (5 madde)
        4) İlişkide iletişim tarzım (3-4 cümle)
        5) Partnerimle daha iyi uyum için öneriler (5 madde)

        Çok genel konuşma, somut ve uygulanabilir yaz.
        """
    }

    private func copyPromptTemplate() {
        UIPasteboard.general.string = promptTemplate
        promptCopied = true
    }

    private func applyIdea(_ seed: String) {
        let current = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let merged = current.isEmpty ? seed : "\(draft)\n\n\(seed)"
        draft = String(merged.prefix(maxLength))
        isEditorFocused = true
    }

    private func triggerDiscoverabilitySync() {
        Task {
            discoverabilityVM.syncFromFirebaseUser()
            await discoverabilityVM.syncDiscoverabilityIndex()
        }
    }
}

@MainActor
private final class NoteSpeechTranscriber: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) ?? SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var baseText = ""
    private var maxLength = 10000

    func toggleRecording(currentText: String, maxLength: Int) {
        if isRecording {
            stopRecording()
            return
        }
        Task { await startRecording(currentText: currentText, maxLength: maxLength) }
    }

    private func startRecording(currentText: String, maxLength: Int) async {
        errorMessage = nil
        self.maxLength = maxLength

        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            errorMessage = "Ses tanıma izni verilmedi. Ayarlar'dan izin verip tekrar dene."
            return
        }

        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            errorMessage = "Mikrofon izni kapalı. Ayarlar'dan izin verip tekrar dene."
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Ses tanıma şu an kullanılamıyor. Birkaç saniye sonra tekrar dene."
            return
        }

        stopRecording()

        baseText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        transcribedText = currentText

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    let spoken = result.bestTranscription.formattedString
                    let joined = self.baseText.isEmpty ? spoken : "\(self.baseText) \(spoken)"
                    self.transcribedText = String(joined.prefix(self.maxLength))
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            stopRecording()
            errorMessage = "Sesli yazma başlatılamadı: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
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

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

#Preview {
    NavigationStack {
        PrivateNoteView(note: .constant("Ben genelde tartışmada sakin kalmaya çalışırım."))
    }
}

