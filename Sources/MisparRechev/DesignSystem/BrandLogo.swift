import SwiftUI
import UIKit

/// The manufacturer's badge on a white tile (logos are drawn for light
/// backgrounds, so the tile stays white in dark mode too). Falls back to the
/// brand's first letter when no logo is bundled.
struct BrandLogo: View {
    let brand: CarBrand?
    /// Used for the monogram when the brand is unknown.
    var fallbackName: String? = nil
    var size: CGFloat = 56

    private var image: UIImage? {
        guard let slug = brand?.slug else { return nil }
        return UIImage(named: "Brands/\(slug)")
    }

    private var monogram: String {
        let source = brand?.name ?? fallbackName ?? ""
        return source.first.map { String($0) } ?? "?"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(.white)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.13)
            } else {
                Text(monogram)
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.25))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
