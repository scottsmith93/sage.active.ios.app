import AVFAudio
import Combine
import Lottie
import PDFKit
import SwiftUI
import UIKit

/// The short-lived states in the speech-to-invoice prototype. There is deliberately no
/// transcript state: the spoken request is represented by the recording and then by the
/// fictional draft invoice that the prototype prepares.
private enum SpeechInvoicePhase: Equatable {
    case idle
    case listening
    case transcribing
    case draft
    case permissionDenied
}

@MainActor
private final class SpeechInvoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var levels = Array(repeating: CGFloat(0.16), count: 48)
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var reachedLimit = false

    private let maximumDuration: TimeInterval = 30
    private var recorder: AVAudioRecorder?
    private var monitorTask: Task<Void, Never>?

    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else {
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("speech-to-invoice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else { return false }

            self.recorder = recorder
            elapsed = 0
            reachedLimit = false
            levels = Array(repeating: CGFloat(0.16), count: 48)
            startMonitoring()
            return true
        } catch {
            return false
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        monitorTask?.cancel()
        monitorTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func discard() {
        stop()
        elapsed = 0
        reachedLimit = false
        levels = Array(repeating: CGFloat(0.16), count: 48)
    }

    private func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard let self, !Task.isCancelled else { return }
                updateMeters()
            }
        }
    }

    private func updateMeters() {
        guard let recorder else { return }
        recorder.updateMeters()

        let power = recorder.averagePower(forChannel: 0)
        let normalized = max(0.08, min(1, (power + 50) / 50))
        levels.removeFirst()
        levels.append(CGFloat(normalized))

        elapsed = min(maximumDuration, elapsed + 0.08)
        if elapsed >= maximumDuration {
            reachedLimit = true
            stop()
        }
    }
}

struct SpeechToInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var recorder = SpeechInvoiceRecorder()
    @State private var phase: SpeechInvoicePhase = .idle
    @State private var selectedDetent: PresentationDetent = .fraction(0.5)
    @State private var loadingMessage = "Transcribing"
    @State private var loadingPlaybackMode = LottiePlaybackMode.paused(at: .currentFrame)
    @State private var showsPrivacyNotice = false
    @State private var transcriptionTask: Task<Void, Never>?

    private let loadingMessages = [
        "Transcribing",
        "Finding customer",
        "Adding products",
        "Preparing invoice",
    ]

    var body: some View {
        NavigationStack {
            content
                .id(phase)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .navigationTitle(phase == .draft ? "Sales invoice" : "Speech to invoice")
                .navigationBarTitleDisplayMode(phase == .draft ? .large : .inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if phase == .draft {
                            SpeechDraftToolbarButton(icon: .close, label: "Close sales invoice", action: dismiss.callAsFunction)
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                SageCarbonIconView(
                                    .close,
                                    pointSize: 20,
                                    color: SageActiveTheme.primaryText
                                )
                            }
                            .accessibilityLabel("Close speech to invoice")
                        }
                    }
                    if phase == .draft {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            SpeechDraftToolbarButton(icon: .edit, label: "Edit invoice") { }
                            SpeechDraftToolbarButton(icon: .delete, label: "Delete invoice") { }
                        }
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: phase)
        }
        .presentationDetents(
            [.fraction(0.28), .fraction(0.5), .large],
            selection: $selectedDetent
        )
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            ContainerRelativeShape()
                .fill(.regularMaterial)
                .overlay {
                    ContainerRelativeShape()
                        .inset(by: 1)
                        .stroke(
                            SageActiveTheme.speechButtonGradient.opacity(0.5),
                            lineWidth: 2
                        )
                }
        }
        .interactiveDismissDisabled(phase == .listening)
        .sheet(isPresented: $showsPrivacyNotice) {
            SpeechPrivacyNoticeSheet()
        }
        .onDisappear {
            recorder.stop()
            transcriptionTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            idleContent.transition(speechContentTransition)
        case .listening:
            listeningContent.transition(speechContentTransition)
        case .transcribing:
            transcribingContent.transition(speechContentTransition)
        case .draft:
            draftInvoiceContent.transition(speechContentTransition)
        case .permissionDenied:
            permissionDeniedContent.transition(speechContentTransition)
        }
    }

    private var speechContentTransition: AnyTransition {
        reduceMotion
            ? .identity
            : .opacity.combined(with: .scale(scale: 0.98, anchor: .center))
    }

    private var idleContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            exampleContent

            Spacer(minLength: 12)

            HStack(spacing: 16) {
                Text("Tap to start creating")
                    .font(.subheadline)
                    .foregroundStyle(SageActiveTheme.primaryText)

                Spacer(minLength: 8)

                SpeechCircleButton(
                    icon: .microphone,
                    accessibilityLabel: "Start recording",
                    style: .outline,
                    action: startRecording
                )
            }
            .padding(.horizontal, SageActiveTheme.pageSpacing)
            .padding(.bottom, 12)

            privacyNotice
        }
        .padding(.bottom, 24)
    }

    private var listeningContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            exampleContent

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                HStack {
                    Label {
                        Text(recorder.reachedLimit ? "Recording complete" : "Listening")
                    } icon: {
                        Circle()
                            .fill(SageActiveTheme.negativeVisual)
                            .frame(width: 8, height: 8)
                    }
                    .font(.subheadline)
                    .foregroundStyle(SageActiveTheme.primaryText)

                    Spacer()

                    Text(timerText)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(SageActiveTheme.primaryText)
                }

                // Keep the waveform's breathing room fixed at 16pt on both sides.
                HStack(spacing: SageActiveTheme.pageSpacing) {
                    SpeechCircleButton(
                        icon: .delete,
                        accessibilityLabel: "Discard recording",
                        style: .outline,
                        action: discardRecording
                    )

                    SpeechWaveform(
                        levels: recorder.levels,
                        reduceMotion: reduceMotion
                    )
                    .frame(maxWidth: .infinity)

                    SpeechCircleButton(
                        icon: .arrowRight,
                        accessibilityLabel: "Send recording",
                        style: .primary,
                        action: sendRecording
                    )
                }
            }
            .padding(.horizontal, SageActiveTheme.pageSpacing)
            .padding(.bottom, 12)

            privacyNotice
        }
        .padding(.bottom, 24)
    }

    private var transcribingContent: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                LottieView {
                    try await DotLottieFile.named("loader-sparkle-loop-v6a")
                } placeholder: {
                    Color.clear
                }
                .playbackMode(loadingPlaybackMode)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityLabel("Preparing invoice")

                Text(loadingMessage)
                    .font(.subheadline)
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: loadingMessage)
            }

            Spacer()

            privacyNotice
        }
        .padding(.horizontal, SageActiveTheme.pageSpacing)
        .padding(.bottom, 24)
        .onAppear {
            loadingPlaybackMode = reduceMotion
                ? .paused(at: .currentFrame)
                : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
        }
        .onDisappear {
            loadingPlaybackMode = .paused(at: .currentFrame)
        }
    }

    private var draftInvoiceContent: some View {
        SpeechDraftInvoiceContent()
    }

    private var permissionDeniedContent: some View {
        ContentUnavailableView {
            Label("Microphone access required", systemImage: "mic.slash")
        } description: {
            Text("Allow microphone access in Settings to record a spoken invoice request.")
        } actions: {
            Button("Try again") {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
            .tint(SageActiveTheme.brand)
        }
        .padding(.horizontal, SageActiveTheme.pageSpacing)
    }

    private var exampleContent: some View {
        VStack(spacing: 8) {
            Image("speech-copilot-logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            Text("To get started, say something like…")
                .font(.subheadline.italic())
                .foregroundStyle(SageActiveTheme.primaryText)

            Text("“Create a sales invoice for Blue Moon Cafe. Add a crate of bottled water and a box of House Blend Coffee”")
                .font(.body.italic())
                .foregroundStyle(SageActiveTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SageActiveTheme.pageSpacing)
        .transition(.opacity)
    }

    private var privacyNotice: some View {
        HStack(spacing: 0) {
            Text("Check AI-generated content for inaccuracies. ")
                .foregroundStyle(SageActiveTheme.supportingText)

            Button("Privacy Notice") {
                showsPrivacyNotice = true
            }
            .foregroundStyle(SageActiveTheme.brand)
            .underline()
            .buttonStyle(.plain)
            .accessibilityHint("Opens the privacy notice")
        }
        .font(.caption2)
        .multilineTextAlignment(.center)
    }

    private var timerText: String {
        let remaining = max(0, Int(30 - recorder.elapsed.rounded(.down)))
        return String(format: "00:%02d", remaining)
    }

    private func startRecording() {
        Task {
            let started = await recorder.start()
            if started {
                animate {
                    phase = .listening
                    selectedDetent = .fraction(0.5)
                }
            } else {
                animate { phase = .permissionDenied }
            }
        }
    }

    private func discardRecording() {
        recorder.discard()
        animate {
            phase = .idle
            selectedDetent = .fraction(0.5)
        }
    }

    private func sendRecording() {
        recorder.stop()
        animate {
            phase = .transcribing
            selectedDetent = .fraction(0.28)
        }

        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor in
            for message in loadingMessages {
                guard !Task.isCancelled else { return }
                loadingMessage = message
                // Four messages at 1.05 seconds gives the prototype a deliberate
                // 4–5 second processing moment without implying real processing time.
                try? await Task.sleep(nanoseconds: 1_050_000_000)
            }

            guard !Task.isCancelled else { return }
            animate {
                phase = .draft
                selectedDetent = .large
            }
        }
    }

    private func animate(_ changes: () -> Void) {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
        } else {
            withAnimation(.easeInOut(duration: 0.32), changes)
        }
    }
}

private struct SpeechPrivacyNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SpeechPrivacyNoticePDFView()
                .background(SageActiveTheme.pageBackground)
                .navigationTitle("Privacy Notice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            SageCarbonIconView(
                                .close,
                                pointSize: 20,
                                color: SageActiveTheme.primaryText
                            )
                        }
                        .accessibilityLabel("Close privacy notice")
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SageActiveTheme.pageBackground)
    }
}

private struct SpeechPrivacyNoticePDFView: UIViewRepresentable {
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(data: SpeechPrivacyNoticeDocument.data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.autoScales = true
    }
}

/// Fictional, local notice content for the prototype. It is deliberately generated
/// in memory so the interaction can be demonstrated without a network dependency
/// or implying that this prototype is production/legal documentation.
private enum SpeechPrivacyNoticeDocument {
    static var data: Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label,
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 6
                    return style
                }(),
            ]

            NSString(string: "Privacy Notice")
                .draw(at: CGPoint(x: 48, y: 56), withAttributes: titleAttributes)

            let body = """
            Prototype notice

            This fictional prototype uses microphone input to demonstrate a speech-to-invoice interaction. Audio is recorded only while the recording control is active, then discarded after the demonstration flow completes.

            The invoice, customer, and product information shown in this prototype is fictional. No real customer records, bank connections, or financial submissions are made.

            Please review any AI-generated content before relying on it. This notice is included for demonstration purposes only and is not a legal or production privacy policy.
            """

            NSString(string: body)
                .draw(
                    in: CGRect(x: 48, y: 112, width: 516, height: 600),
                    withAttributes: bodyAttributes
                )
        }
    }
}

private struct SpeechWaveform: View {
    let levels: [CGFloat]
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(SageActiveTheme.secondaryUtility25)
                    .frame(width: 2, height: max(4, level * 32))
            }
        }
        .frame(height: 32)
        .clipped()
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: levels)
        .accessibilityLabel("Live recording waveform")
    }
}

private struct SpeechCircleButton: View {
    enum Style {
        case outline
        case primary
    }

    let icon: SageCarbonIcon
    let accessibilityLabel: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SageCarbonIconView(
                icon,
                pointSize: 20,
                color: style == .primary ? SageActiveTheme.white : SageActiveTheme.primaryText
            )
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .background(background)
        .clipShape(Circle())
        .overlay { border }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .outline:
            Color.clear.glassEffect(.regular.interactive(), in: Circle())
        case .primary:
            SageActiveTheme.brand
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .outline:
            Circle().stroke(SageActiveTheme.brand, lineWidth: 1.5)
        case .primary:
            EmptyView()
        }
    }
}
