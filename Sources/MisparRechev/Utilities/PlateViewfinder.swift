import CoreGraphics

/// Shared geometry for the plate scanner: the visual cutout, the VisionKit
/// region of interest, and the geometry-acceptance region all derive from
/// here so they can never disagree. Coordinates are the full-bleed scanner
/// view's UIKit space (top-left origin, points) — the same space VisionKit's
/// `RecognizedItem.bounds` and the SwiftUI overlay use.
enum PlateViewfinder {
    /// Cutout width as a fraction of the view width.
    static let widthFraction: CGFloat = 0.85
    /// Israeli plate aspect ratio (520×110 mm ≈ 4.73; 4.6 is slightly
    /// taller — forgiving to aim with).
    static let aspectRatio: CGFloat = 4.6
    /// Aim tolerance added on each side of the cutout: fraction of cutout
    /// height (vertically) and of cutout width (horizontally).
    static let verticalTolerance: CGFloat = 0.4
    static let horizontalTolerance: CGFloat = 0.06
    /// Minimum text height for a fragment to count as plate digits, as a
    /// fraction of cutout height. Plate digits are ~0.7× plate height, so
    /// this still admits a plate filling only ~36% of the cutout, while
    /// dealer-frame text (~0.15–0.23× plate height) can never reach it.
    static let minimumTextHeightFraction: CGFloat = 0.25

    /// The visual cutout: `widthFraction` wide, plate aspect, centered.
    static func cutout(in size: CGSize) -> CGRect {
        let width = size.width * widthFraction
        let height = width / aspectRatio
        return CGRect(x: (size.width - width) / 2,
                      y: (size.height - height) / 2,
                      width: width, height: height)
    }

    /// The cutout expanded by the aim tolerances — used both as the
    /// VisionKit `regionOfInterest` and as the geometry-acceptance region.
    static func acceptanceRegion(for cutout: CGRect) -> CGRect {
        cutout.insetBy(dx: -cutout.width * horizontalTolerance,
                       dy: -cutout.height * verticalTolerance)
    }

    /// `acceptanceRegion` for a view of `size`, clamped to the view bounds.
    static func regionOfInterest(in size: CGSize) -> CGRect {
        acceptanceRegion(for: cutout(in: size))
            .intersection(CGRect(origin: .zero, size: size))
    }
}
