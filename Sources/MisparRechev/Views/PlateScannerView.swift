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
        let width = view.bounds.width
        let height = view.bounds.height
        guard width > 0, height > 0 else { return }
        // Recognize only a horizontal band around the plate cutout (which is
        // 85% width × 4.6:1, centered — see PlateScannerSheet). 3× the cutout
        // height forgives shaky aim while skipping bumper stickers, signs and
        // other text that would slow recognition down and cause false locks.
        let bandHeight = min(max(width * 0.85 / 4.6 * 3, 160), height)
        scanner.regionOfInterest = CGRect(
            x: 0, y: (height - bandHeight) / 2, width: width, height: bandHeight
        )
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
        return scanner.withHost(onUnavailable: onUnavailable)
    }

    func updateUIViewController(_ host: PlateScannerHostController, context: Context) {}

    static func dismantleUIViewController(_ host: PlateScannerHostController,
                                          coordinator: Coordinator) {
        host.scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPlateFound: onPlateFound) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onPlateFound: (String) -> Void
        private var lastCandidate: String?
        private var stableCount = 0
        private var accepted = false

        init(onPlateFound: @escaping (String) -> Void) {
            self.onPlateFound = onPlateFound
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
                         didTapOn item: RecognizedItem) {
            guard case .text(let text) = item,
                  let plate = PlateRecognizer.extractPlate(from: text.transcript) else { return }
            accept(plate)
        }

        private func consider(_ items: [RecognizedItem]) {
            guard !accepted else { return }
            let transcripts = items.compactMap { item -> String? in
                if case .text(let text) = item { return text.transcript }
                return nil
            }
            guard let best = PlateRecognizer.bestCandidate(in: transcripts) else { return }

            // A read in the exact Israeli print format (3-2-3 / 2-3-2) is a
            // complete plate — accept it immediately, no stability wait.
            if best.isCanonicalFormat {
                accept(best.digits)
                return
            }
            // Otherwise require the same read across consecutive frames —
            // one frame's OCR can misread or truncate a digit. Legacy 6-digit
            // reads need an extra frame, since they are also what a partially
            // captured 7–8-digit plate looks like.
            if best.digits == lastCandidate {
                stableCount += 1
            } else {
                lastCandidate = best.digits
                stableCount = 1
            }
            if stableCount >= (best.digits.count >= 7 ? 2 : 3) {
                accept(best.digits)
            }
        }

        private func accept(_ plate: String) {
            guard !accepted else { return }
            accepted = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onPlateFound(plate)
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

    var body: some View {
        ZStack {
            if isUnavailable {
                permissionFallback
            } else {
                DataScannerRepresentable(
                    onPlateFound: onPlateFound,
                    onUnavailable: { isUnavailable = true }
                )
                .ignoresSafeArea()
                viewfinderOverlay
            }

            VStack {
                Spacer()
                if !isUnavailable {
                    Text("כוונו את המצלמה ללוחית הרישוי")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.m)
                        .background(Capsule().fill(.black.opacity(0.55)))
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

    /// Dimmed overlay with a clear plate-aspect window in the middle.
    private var viewfinderOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.85
            let height = width / 4.6 // Israeli plate aspect ratio ≈ 520×110mm
            ZStack {
                Color.black.opacity(0.45)
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .frame(width: width, height: height)
                    .blendMode(.destinationOut)
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .strokeBorder(Theme.Colors.plateYellow, lineWidth: 3)
                    .frame(width: width, height: height)
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
