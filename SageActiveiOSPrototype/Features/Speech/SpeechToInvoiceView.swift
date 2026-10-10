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
    case permissionDenied
}

/// Preserves the native sheet material independently from its decorative border. Keeping
/// this as the presentation background lets the system own the sheet's physical shape.
private struct CopilotSheetSurface: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Ultra-thin material keeps the content beneath the sheet visible as
            // a restrained blur instead of resolving to an opaque-looking panel.
            Rectangle()
                .fill(.ultraThinMaterial)

            Group {
                if colorScheme == .dark {
                    SageActiveTheme.secondaryUtility10
                } else {
                    SageActiveTheme.cardBackground
                }
            }
            .opacity(colorScheme == .dark ? 0.68 : 0.58)
        }
        // Apply 80% to the complete material-and-tint composite. Applying it only
        // to the tint left the material beneath fully filled and visually solid.
        .compositingGroup()
        .opacity(0.80)
    }
}

/// Draws the Copilot stroke inside the sheet content instead of relying on the presentation
/// background's clipping path. iOS 26 and iOS 27 clip custom presentation backgrounds
/// differently; a concentric content overlay remains aligned with the device on both.
private struct AnimatedCopilotSheetBorder: View {
    private let lineWidth: CGFloat = 2

    var body: some View {
        CopilotGradientStroke(
            shape: ConcentricRectangle(
                uniformTopCorners: .concentric(minimum: 30),
                uniformBottomCorners: .concentric
            ),
            lineWidth: lineWidth,
            opacity: 0.5
        )
        // Keep the full stroke inside the system presentation boundary.
        .padding(lineWidth / 2)
        .ignoresSafeArea()
    }
}

@MainActor
private final class SpeechInvoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var levels = Array(repeating: CGFloat(0.16), count: 54)
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
            levels = Array(repeating: CGFloat(0.16), count: 54)
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
        levels = Array(repeating: CGFloat(0.16), count: 54)
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

/// Vertical measurements for the two speech-sheet states. Every app-owned value
/// sits on the 8pt spacing grid; the native navigation bar remains system-owned.
private enum SpeechInvoiceLayout {
    static let toolbarRegion: CGFloat = 56
    static let contentTopPadding: CGFloat = 16
    static let exampleRegion: CGFloat = 112
    static let controlSpacing: CGFloat = 24
    static let controlHeight: CGFloat = 48
    static let disclaimerSpacing: CGFloat = 24
    static let disclaimerLineRegion: CGFloat = 16
    static let bottomPadding: CGFloat = 24
    static let loaderHeight: CGFloat = 72
    static let loaderSpacing: CGFloat = 16
    static let loaderLabelRegion: CGFloat = 24

    static let entryContentHeight = exampleRegion + controlSpacing + controlHeight
    static let disclaimerRegion = disclaimerLineRegion + bottomPadding
    static let loaderRegion = loaderHeight + loaderSpacing + loaderLabelRegion

    static let expandedSheetHeight =
        toolbarRegion
        + contentTopPadding
        + entryContentHeight
        + disclaimerSpacing
        + disclaimerRegion

    static let preparingSheetHeight =
        toolbarRegion
        + contentTopPadding
        + loaderRegion
        + disclaimerSpacing
        + disclaimerRegion
}

struct SpeechToInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var recordingGlassNamespace

    @StateObject private var recorder = SpeechInvoiceRecorder()
    @State private var phase: SpeechInvoicePhase = .idle
    @State private var recordingControlsVisible = false
    @State private var microphoneVisible = true
    @State private var entryContentVisible = true
    @State private var loadingContentVisible = false
    @State private var selectedDetent: PresentationDetent = .height(
        SpeechInvoiceLayout.expandedSheetHeight
    )
    @State private var allowedDetents: Set<PresentationDetent> = [
        .height(SpeechInvoiceLayout.expandedSheetHeight)
    ]
    @State private var loadingMessage = "Transcribing"
    @State private var loadingPlaybackMode = LottiePlaybackMode.paused(at: .currentFrame)
    @State private var showsPrivacyNotice = false
    @State private var showsDraftInvoice = false
    @State private var recordingRevealTask: Task<Void, Never>?
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .navigationTitle("Speech to Invoice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SageCarbonToolbarButton(
                            icon: .cross,
                            accessibilityLabel: "Close Speech to Invoice",
                            action: dismiss.callAsFunction
                        )
                        .shadow(color: glassControlShadow, radius: 8, y: 2)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .overlay {
            if phase != .permissionDenied {
                // The recording UI and disclaimer share one bottom-anchored stack,
                // making their 24pt relationship explicit. Collapsing the recording
                // region cannot move the disclaimer away from its fixed bottom inset.
                VStack(spacing: SpeechInvoiceLayout.disclaimerSpacing) {
                    recordingEntryContent
                        .frame(
                            height: entryContentVisible
                                ? SpeechInvoiceLayout.entryContentHeight
                                : 0,
                            alignment: .bottom
                        )
                        .opacity(entryContentVisible ? 1 : 0)
                        .allowsHitTesting(entryContentVisible)
                        .accessibilityHidden(!entryContentVisible)

                    privacyNotice
                }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                    .padding(.bottom, SpeechInvoiceLayout.bottomPadding)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .overlay {
            AnimatedCopilotSheetBorder()
        }
        .presentationDetents(
            allowedDetents,
            selection: $selectedDetent
        )
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            CopilotSheetSurface()
        }
        .interactiveDismissDisabled(phase == .listening)
        .sheet(isPresented: $showsPrivacyNotice) {
            SpeechPrivacyNoticeSheet()
        }
        .sheet(isPresented: $showsDraftInvoice, onDismiss: dismiss.callAsFunction) {
            SpeechDraftInvoiceSheet()
        }
        .onDisappear {
            recorder.stop()
            recordingRevealTask?.cancel()
            transcriptionTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .listening, .transcribing:
            recordingWorkflowContent
                .transition(.identity)
        case .permissionDenied:
            permissionDeniedContent.transition(speechContentTransition)
        }
    }

    private var speechContentTransition: AnyTransition {
        reduceMotion
            ? .identity
            : .opacity.combined(with: .scale(scale: 0.98, anchor: .center))
    }

    /// The preparing content occupies the area above the persistent bottom overlay.
    /// Recording content lives in that overlay so its spacing to the disclaimer is
    /// exact instead of being inferred from spare space in a fixed-height sheet.
    private var recordingWorkflowContent: some View {
        ZStack {
            if phase == .transcribing {
                transcribingStatusContent
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
                    .opacity(loadingContentVisible ? 1 : 0)
            }
        }
        .padding(.top, SpeechInvoiceLayout.contentTopPadding)
        .padding(
            .bottom,
            SpeechInvoiceLayout.disclaimerSpacing + SpeechInvoiceLayout.disclaimerRegion
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recordingEntryContent: some View {
        VStack(spacing: 0) {
            exampleContent
                .frame(minHeight: SpeechInvoiceLayout.exampleRegion)

            recordingControl
                .padding(.top, SpeechInvoiceLayout.controlSpacing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: SpeechInvoiceLayout.entryContentHeight, alignment: .bottom)
    }

    private var recordingControl: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                if phase == .listening {
                    recordingPanel
                        .frame(maxWidth: 346, minHeight: 48, maxHeight: 48)
                        .glassEffect(.regular, in: Capsule())
                        .shadow(color: glassControlShadow, radius: 8, y: 2)
                        .glassEffectID("speech-recording-control", in: recordingGlassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                } else {
                    Button(action: startRecording) {
                        Color.clear
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .tint(SageActiveTheme.brand)
                    .controlSize(.large)
                    .frame(width: 48, height: 48)
                    .shadow(color: glassControlShadow, radius: 8, y: 2)
                    .glassEffectID("speech-recording-control", in: recordingGlassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                    .accessibilityLabel("Start recording")
                }

            }
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
        }
        .frame(height: 48)
        .overlay {
            // Keep the icon outside the glass rendering group. Liquid Glass is
            // composited after its children, so an icon inside the container can
            // be obscured by the prominent tint. This fixed overlay participates
            // only in an opacity animation and never moves with the glass morph.
            SageCarbonIconView(
                .microphone,
                pointSize: 20,
                color: colorScheme == .light
                    ? SageActiveTheme.white
                    : SageActiveTheme.primaryActionForeground
            )
            .frame(width: 20, height: 20)
            .opacity(phase == .idle && microphoneVisible ? 1 : 0)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 24)
    }

    private var recordingPanel: some View {
        HStack(spacing: 0) {
            Button(action: discardRecording) {
                SageCarbonIconView(
                    .delete,
                    pointSize: 20,
                    color: SageActiveTheme.negativeVisual
                )
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Discard recording")

            SpeechWaveform(
                levels: recorder.levels,
                reduceMotion: reduceMotion
            )
            .frame(width: 216, height: 32)

            recordingTimer
                .padding(.leading, 8)

            Button(action: sendRecording) {
                SageCarbonIconView(
                    .arrowRight,
                    pointSize: 20,
                    color: SageActiveTheme.white
                )
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(SageActiveTheme.brand)
            .controlSize(.regular)
            .frame(width: 40, height: 40)
            .padding(.leading, 8)
            .accessibilityLabel("Send recording")
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .opacity(recordingControlsVisible ? 1 : 0)
        .scaleEffect(recordingControlsVisible ? 1 : 0.98)
        .allowsHitTesting(recordingControlsVisible)
        .accessibilityHidden(!recordingControlsVisible)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: recordingControlsVisible
        )
    }

    private var recordingTimer: some View {
        Text(timerText)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(SageActiveTheme.primaryText)
            .frame(width: 24, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(recorder.reachedLimit ? "Recording complete" : "Recording")
            .accessibilityValue(timerText)
    }

    private var glassControlShadow: Color {
        .black.opacity(colorScheme == .dark ? 0.30 : 0.14)
    }

    private var transcribingStatusContent: some View {
        VStack(spacing: 16) {
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
        .padding(.horizontal, SageActiveTheme.pageSpacing)
        .onAppear {
            loadingPlaybackMode = reduceMotion
                ? .paused(at: .currentFrame)
                : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
        }
        .onDisappear {
            loadingPlaybackMode = .paused(at: .currentFrame)
        }
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
        VStack(spacing: 16) {
            Image("speech-copilot-logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("To get started, say something like…")
                    .font(.caption2.italic())
                    .foregroundStyle(SageActiveTheme.primaryText)

                Text("“Create a sales invoice for Blue Moon Cafe. Add a crate of bottled water and a box of House Blend Coffee”")
                    .font(.caption.italic())
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 32)
    }

    private var timerText: String {
        let remaining = max(0, Int(30 - recorder.elapsed.rounded(.down)))
        return "\(remaining)s"
    }

    private func startRecording() {
        Task {
            let started = await recorder.start()
            if started {
                beginListeningTransition()
            } else {
                animate { phase = .permissionDenied }
            }
        }
    }

    private func beginListeningTransition() {
        recordingRevealTask?.cancel()
        recordingControlsVisible = false

        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                microphoneVisible = false
                phase = .listening
                selectedDetent = .height(SpeechInvoiceLayout.expandedSheetHeight)
                recordingControlsVisible = true
            }
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            microphoneVisible = false
        }
        withAnimation(.smooth(duration: 0.38)) {
            phase = .listening
            selectedDetent = .height(SpeechInvoiceLayout.expandedSheetHeight)
        }

        recordingRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, phase == .listening else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                recordingControlsVisible = true
            }
        }
    }

    private func discardRecording() {
        // Freeze the current waveform and timer while the controls dissolve. Resetting
        // them before the fade completes creates a visible flash back to the idle data.
        recorder.stop()
        recordingRevealTask?.cancel()

        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                recorder.discard()
                recordingControlsVisible = false
                microphoneVisible = true
                phase = .idle
                selectedDetent = .height(SpeechInvoiceLayout.expandedSheetHeight)
            }
            return
        }

        // Mirror the forward sequence: dissolve the foreground controls, then use
        // the same 380ms liquid-glass morph back to the circular record control.
        withAnimation(.easeIn(duration: 0.12)) {
            recordingControlsVisible = false
        }

        recordingRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, phase == .listening else { return }
            recorder.discard()
            microphoneVisible = false
            withAnimation(.smooth(duration: 0.38)) {
                phase = .idle
                selectedDetent = .height(SpeechInvoiceLayout.expandedSheetHeight)
            }

            // Reveal the icon immediately after the glass has returned to its
            // circular resting shape. Only opacity changes, so it cannot slide.
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled, phase == .idle else { return }
            withAnimation(.easeOut(duration: 0.10)) {
                microphoneVisible = true
            }
        }
    }

    private func sendRecording() {
        recorder.stop()
        recordingRevealTask?.cancel()
        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor in
            if reduceMotion {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    recordingControlsVisible = false
                    entryContentVisible = false
                    phase = .transcribing
                    loadingContentVisible = true
                    allowedDetents = [.height(SpeechInvoiceLayout.preparingSheetHeight)]
                    selectedDetent = .height(SpeechInvoiceLayout.preparingSheetHeight)
                }
            } else {
                // A selection animates only when both source and destination are
                // registered detents. Add the compact detent without changing height,
                // then animate selection and opacity together on the next update.
                var preparationTransaction = Transaction()
                preparationTransaction.disablesAnimations = true
                withTransaction(preparationTransaction) {
                    allowedDetents = [
                        .height(SpeechInvoiceLayout.expandedSheetHeight),
                        .height(SpeechInvoiceLayout.preparingSheetHeight)
                    ]
                }

                // Give SwiftUI one display frame to commit both detents to the
                // presentation controller. A task yield alone can resume before
                // that commit and makes the following selection change snap.
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.30)) {
                    recordingControlsVisible = false
                    entryContentVisible = false
                    selectedDetent = .height(SpeechInvoiceLayout.preparingSheetHeight)
                }

                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                // Lock the presentation back to one detent after the native resize,
                // so the user cannot manually change the sheet height.
                var completionTransaction = Transaction()
                completionTransaction.disablesAnimations = true
                withTransaction(completionTransaction) {
                    allowedDetents = [.height(SpeechInvoiceLayout.preparingSheetHeight)]
                    phase = .transcribing
                }
                withAnimation(.easeIn(duration: 0.30)) {
                    loadingContentVisible = true
                }
            }

            for message in loadingMessages {
                guard !Task.isCancelled else { return }
                loadingMessage = message
                // Four messages at 1.05 seconds gives the prototype a deliberate
                // 4–5 second processing moment without implying real processing time.
                try? await Task.sleep(nanoseconds: 1_050_000_000)
            }

            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
                loadingContentVisible = false
            }

            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
            }

            // The prepared document uses its own standard native sheet. The
            // Copilot border belongs only to the recording and preparation flow.
            showsDraftInvoice = true
        }
    }

    private func animate(_ changes: () -> Void) {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
        } else {
            withAnimation(.smooth(duration: 0.38), changes)
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
                        SageCarbonToolbarButton(
                            icon: .cross,
                            accessibilityLabel: "Close privacy notice",
                            action: dismiss.callAsFunction
                        )
                    }
                    .sharedBackgroundVisibility(.hidden)
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
                    .fill(SageActiveTheme.secondaryUtility75)
                    .frame(width: 2, height: max(4, level * 32))
            }
        }
        .frame(height: 32)
        .clipped()
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: levels)
        .accessibilityLabel("Live recording waveform")
    }
}
