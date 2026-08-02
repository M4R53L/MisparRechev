import SwiftUI
import UIKit
import AVFoundation
import VisionKit

/// Hosts VisionKit's live text scanner tuned for reading an Israeli license
/// plate, and constrains recognition to the viewfinder band via
/// `regionOfInterest` (set on layout, where the view size is known).
final class PlateScannerHostController: UIViewController {
    let scanner: DataScannerViewController
    private let onUnavailable: () -> Void
    /// Reports the scanner view's size on layout — the coordinator caches it
    /// so delegate callbacks never touch UIKit views off the main thread.
    var onViewSizeChange: ((CGSize) -> Void)?

    init(scanner: DataScannerViewController, onUnavailable: @escaping () -> Void) {
        self.scanner = scanner
        self.onUnavailable = onUnavailable
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanner.view.frame = view.bounds
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        // Recognize only around the plate cutout — VisionKit itself then
        // skips bumper stickers, signs and other distant text, and its
        // highlight boxes double as aim feedback near the viewfinder.
        scanner.regionOfInterest = PlateViewfinder.regionOfInterest(in: size)
        onViewSizeChange?(size)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do { try scanner.startScanning() } catch { onUnavailable() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopScanning()
    }
}

/// SwiftUI wrapper around the scanner host. Reports the plate via
/// `onPlateFound` (digits only).
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onPlateFound: (String) -> Void
    /// Live feedback: the best plate read so far (nil when nothing
    /// plate-shaped is in view). Drives the tappable candidate pill.
    let onCandidate: (PlateRecognizer.Candidate?) -> Void
    /// Called when the scanner cannot start (e.g. camera permission denied).
    let onUnavailable: () -> Void

    func makeUIViewController(context: Context) -> PlateScannerHostController {
        let scanner = DataScannerViewController(
            // Plates are digits — a single Latin recognition model is faster
            // and no less capable here than adding Hebrew.
            recognizedDataTypes: [.text(languages: ["en"])],
            qualityLevel: .balanced,
            // Multiple items is essential: with a single item the scanner
            // often locks onto a dealer sticker or bumper text instead of the
            // plate. We rank all items and pick the best plate-shaped read.
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        let host = scanner.withHost(onUnavailable: onUnavailable)
        host.onViewSizeChange = { [weak coordinator = context.coordinator] size in
            coordinator?.viewSize = size
        }
        return host
    }

    func updateUIViewController(_ host: PlateScannerHostController, context: Context) {}

    static func dismantleUIViewController(_ host: PlateScannerHostController,
                                          coordinator: Coordinator) {
        host.scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlateFound: onPlateFound, onCandidate: onCandidate)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onPlateFound: (String) -> Void
        private let onCandidate: (PlateRecognizer.Candidate?) -> Void
        private var lastCandidate: String?
        private var stableCount = 0
        private var accepted = false
        private var lastItems: [RecognizedItem] = []
        private var reportedCandidate: PlateRecognizer.Candidate?
        /// Scanner view size, cached from layout so delegate callbacks never
        /// read UIKit views off the main thread.
        var viewSize: CGSize = .zero

        init(onPlateFound: @escaping (String) -> Void,
             onCandidate: @escaping (PlateRecognizer.Candidate?) -> Void) {
            self.onPlateFound = onPlateFound
            self.onCandidate = onCandidate
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            consider(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            consider(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didRemove removedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            // Keeps the candidate pill honest — it hides when the plate
            // leaves the viewfinder.
            consider(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didTapOn item: RecognizedItem) {
            guard case .text = item else { return }
            // Prefer the read already shown in the pill; otherwise re-derive
            // from the last frame — tapping any part of the plate accepts the
            // full plate read, not just the tapped digit group.
            if let candidate = reportedCandidate {
                accept(candidate.digits)
                return
            }
            let transcripts = PlateRecognizer.plateTranscripts(
                from: observations(from: lastItems))
            guard let best = PlateRecognizer.bestCandidate(in: transcripts) else { return }
            accept(best.digits)
        }

        private func consider(_ items: [RecognizedItem]) {
            guard !accepted else { return }
            lastItems = items
            guard viewSize != .zero else { return }
            let frameObservations = observations(from: items)
            let cutout = PlateViewfinder.cutout(in: viewSize)

            // Auto-accept path: only text geometrically verified as the aimed
            // plate — inside the cutout, at plate-digit size.
            let geometry = PlateRecognizer.viewfinderCandidate(
                from: frameObservations, cutout: cutout)
            // Fallback: anything plate-shaped in the ROI — powers the pill
            // and a slower accept when the size filter misjudges (e.g. the
            // user aiming from afar).
            let best = geometry ?? PlateRecognizer.bestCandidate(
                in: PlateRecognizer.plateTranscripts(from: frameObservations))
            report(best)
            guard let best else { return }

            // Require the same read across consecutive frames; how many
            // depends on how trustworthy the read's shape and geometry are
            // (canonical/single-run in-cutout reads accept on frame one).
            if best.digits == lastCandidate {
                stableCount += 1
            } else {
                lastCandidate = best.digits
                stableCount = 1
            }
            if stableCount >= PlateRecognizer.framesRequired(
                for: best, geometryVerified: geometry != nil) {
                accept(best.digits)
            }
        }

        /// Maps VisionKit items into the recognizer's geometry-bearing
        /// fragments so split digit groups can be merged back into a plate.
        private func observations(from items: [RecognizedItem]) -> [PlateRecognizer.TextObservation] {
            items.compactMap { item in
                guard case .text(let text) = item else { return nil }
                let bounds = item.bounds
                let topY = (bounds.topLeft.y + bounds.topRight.y) / 2
                let bottomY = (bounds.bottomLeft.y + bounds.bottomRight.y) / 2
                return PlateRecognizer.TextObservation(
                    transcript: text.transcript,
                    minX: Double(min(bounds.topLeft.x, bounds.bottomLeft.x)),
                    maxX: Double(max(bounds.topRight.x, bounds.bottomRight.x)),
                    midY: Double(topY + bottomY) / 2,
                    height: abs(Double(bottomY - topY))
                )
            }
        }

        private func report(_ candidate: PlateRecognizer.Candidate?) {
            guard candidate != reportedCandidate else { return }
            reportedCandidate = candidate
            let onCandidate = onCandidate
            // Delegate queue isn't documented as main — hop before touching
            // SwiftUI state.
            DispatchQueue.main.async { onCandidate(candidate) }
        }

        private func accept(_ plate: String) {
            guard !accepted else { return }
            accepted = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let onPlateFound = onPlateFound
            DispatchQueue.main.async { onPlateFound(plate) }
        }
    }
}

private extension DataScannerViewController {
    func withHost(onUnavailable: @escaping () -> Void) -> PlateScannerHostController {
        PlateScannerHostController(scanner: self, onUnavailable: onUnavailable)
    }
}

/// The scanner sheet: full-bleed camera with a plate-shaped viewfinder cutout,
/// Hebrew guidance, a torch toggle for low light, and a cancel button. Falls
/// back to a permission message when the camera can't start.
struct PlateScannerSheet: View {
    let onPlateFound: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isUnavailable = false
    @State private var isTorchOn = false
    @State private var liveCandidate: PlateRecognizer.Candidate?

    var body: some View {
        ZStack {
            if isUnavailable {
                permissionFallback
            } else {
                DataScannerRepresentable(
                    onPlateFound: onPlateFound,
                    onCandidate: { liveCandidate = $0 },
                    onUnavailable: { isUnavailable = true }
                )
                .ignoresSafeArea()
                viewfinderOverlay
            }

            VStack {
                Spacer()
                if !isUnavailable {
                    VStack(spacing: Theme.Spacing.s) {
                        Text("כוונו את המצלמה ללוחית הרישוי")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.vertical, Theme.Spacing.m)
                            .background(Capsule().fill(.black.opacity(0.55)))
                        if let liveCandidate {
                            candidatePill(liveCandidate)
                        }
                    }
                    .padding(.bottom, Theme.Spacing.l)
                }
                HStack(spacing: Theme.Spacing.xxl) {
                    if !isUnavailable {
                        torchButton
                    }
                    Button("ביטול") { dismiss() }
                        .font(Theme.Typography.headline)
                        .foregroundStyle(isUnavailable ? Theme.Colors.primary : .white)
                        .accessibilityLabel("ביטול סריקה")
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear { setTorch(false) }
    }

    // MARK: - Live candidate

    /// The best plate read so far, shown as printed ("123-45-678"). Tapping
    /// accepts it immediately — a manual escape hatch when OCR flicker keeps
    /// the auto-lock from converging.
    private func candidatePill(_ candidate: PlateRecognizer.Candidate) -> some View {
        Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onPlateFound(candidate.digits)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Text("זוהה:")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                Text(PlateRecognizer.formatted(candidate))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.plateYellow)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background(Capsule().fill(.black.opacity(0.55)))
        }
        .accessibilityLabel("אישור המספר שזוהה")
        .accessibilityHint("מפעיל חיפוש עבור המספר שזוהה במצלמה")
    }

    // MARK: - Torch

    private var torchButton: some View {
        Button {
            isTorchOn.toggle()
            setTorch(isTorchOn)
        } label: {
            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isTorchOn ? Theme.Colors.plateYellow : .white)
                .padding(10)
                .background(Circle().fill(.black.opacity(0.55)))
        }
        .accessibilityLabel(isTorchOn ? "כיבוי פנס" : "הדלקת פנס")
    }

    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: - Viewfinder

    /// Dimmed overlay with a clear plate-aspect window in the middle. The
    /// window is `PlateViewfinder.cutout` — the same rect the recognizer
    /// accepts text in, so what the user sees is what gets read.
    private var viewfinderOverlay: some View {
        GeometryReader { proxy in
            let cutout = PlateViewfinder.cutout(in: proxy.size)
            ZStack {
                Color.black.opacity(0.45)
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .frame(width: cutout.width, height: cutout.height)
                    .blendMode(.destinationOut)
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .strokeBorder(Theme.Colors.plateYellow, lineWidth: 3)
                    .frame(width: cutout.width, height: cutout.height)
            }
            .compositingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false) // let taps reach the scanner's tap-to-accept
    }

    // MARK: - Permission fallback

    private var permissionFallback: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.Colors.neutral)
            Text("אין גישה למצלמה")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("כדי לסרוק לוחית רישוי יש לאשר גישה למצלמה בהגדרות")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("פתיחת הגדרות")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textOnPrimary)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .frame(minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .fill(Theme.Colors.primary)
                    )
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
