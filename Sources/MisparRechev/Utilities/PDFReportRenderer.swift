import SwiftUI

/// Renders `PDFReportView` into a single-page **vector** PDF (crisp text at
/// any zoom) sized to its content, saved to the temp directory.
@MainActor
enum PDFReportRenderer {
    enum RenderError: Error {
        case contextCreationFailed
    }

    /// Returns the URL of "דוח-רכב-<plate>.pdf" in the temp directory.
    ///
    /// The RTL/Hebrew/light environment is applied to the rendered content
    /// itself — `ImageRenderer` does not inherit the app's environment.
    static func render(result: LookupResult, generatedAt: Date = .now) throws -> URL {
        let content = PDFReportView(result: result, generatedAt: generatedAt)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he_IL"))
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: PDFReportView.pageWidth,
                                                 height: nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("דוח-רכב-\(result.vehicle.mispar_rechev).pdf")

        var rendered = false
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
                return
            }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            rendered = true
        }
        guard rendered else { throw RenderError.contextCreationFailed }
        return url
    }
}
