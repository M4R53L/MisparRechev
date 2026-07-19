import SwiftUI
import UIKit
import VisionKit

/// SwiftUI wrapper around VisionKit's live text scanner, tuned for reading an
/// Israeli license plate. Reports the plate via `onPlateFound` (digits only).
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onPlateFound: (String) -> Void
    /// Called when the scanner cannot start (e.g. camera permission denied).
    let onUnavailable: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["he", "en"])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            onUnavailable()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController,
                                          coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPlateFound: onPlateFound) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onPlateFound: (String) -> Void
        /// Auto-accept only after the same plate is seen in consecutive
        /// callbacks — a single frame's OCR can misread a digit.
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
            for item in items {
                guard case .text(let text) = item,
                      let plate = PlateRecognizer.extractPlate(from: text.transcript) else { continue }
                if plate == lastCandidate {
                    stableCount += 1
                    if stableCount >= 2 { accept(plate) }
                } else {
                    lastCandidate = plate
                    stableCount = 1
                }
                return
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

/// The scanner sheet: full-bleed camera with a plate-shaped viewfinder cutout,
/// Hebrew guidance, and a cancel button. Falls back to a permission message
/// when the camera can't start.
struct PlateScannerSheet: View {
    let onPlateFound: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isUnavailable = false

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
                Button("ביטול") { dismiss() }
                    .font(Theme.Typography.headline)
                    .foregroundStyle(isUnavailable ? Theme.Colors.primary : .white)
                    .padding(.bottom, Theme.Spacing.xl)
                    .accessibilityLabel("ביטול סריקה")
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

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
