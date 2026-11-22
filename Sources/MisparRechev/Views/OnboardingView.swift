import SwiftUI

enum Onboarding {
    /// UserDefaults key. Pass `-hasSeenOnboarding YES` as a launch argument to
    /// skip the guide (UI tests do).
    static let seenKey = "hasSeenOnboarding"
    /// A known-good public test plate offered as the example.
    static let examplePlate = "5970065"
}

/// First-run guide. One idea per screen, a progress bar that fills as you go,
/// and it ends by doing the real thing: typing a plate and opening its report.
struct OnboardingView: View {
    /// Called when the guide ends. The plate is non-nil when the user chose to
    /// look one up as the last step.
    let onFinish: (String?) -> Void

    private enum Step: Int, CaseIterable {
        case welcome, report, scan, myCar, tryIt
    }

    @State private var step: Step = .welcome
    @State private var movingForward = true
    @State private var plate = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var plateIsValid: Bool { (6...8).contains(plate.count) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)

            ZStack {
                page
                    .id(step)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .interactiveDismissDisabled()
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity))
    }

    private func go(to next: Step) {
        movingForward = next.rawValue > step.rawValue
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            step = next
        }
    }

    // MARK: - Top bar (back, progress, skip)

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) { go(to: previous) }
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)
            .accessibilityLabel("לשלב הקודם")

            OnboardingProgressBar(progress: Double(step.rawValue + 1) / Double(Step.allCases.count))
                .accessibilityLabel("שלב \(step.rawValue + 1) מתוך \(Step.allCases.count)")

            Button("דילוג") { onFinish(nil) }
                .font(Theme.Typography.bodyBold)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:
            OnboardingPage(
                title: "כל רכב בישראל, לפי המספר שלו",
                message: "מקלידים מספר רישוי ומקבלים את המידע הרשמי של משרד התחבורה. בלי הרשמה ובלי פרסומות."
            ) { RollingPlate() }
        case .report:
            OnboardingPage(
                title: "מה תדעו על הרכב",
                message: "כל מה שכדאי לבדוק לפני שקונים רכב יד שנייה, במסך אחד."
            ) { HighlightsReveal() }
        case .scan:
            OnboardingPage(
                title: "אפשר גם לסרוק",
                message: "מכוונים את המצלמה אל הלוחית והמספר מזוהה מעצמו. התמונה לא נשמרת ולא נשלחת לשום מקום."
            ) { ScanIllustration() }
        case .myCar:
            OnboardingPage(
                title: "הרכב שלכם תמיד במעקב",
                message: "מסמנים את הרכב בכוכב ומקבלים תזכורת לפני שהטסט פג, והתראה אם נפתח ריקול חדש."
            ) {
                MyCarCard(car: .init(plate: 5970065, title: "MX 5, 2008",
                                     tokefDt: Self.sampleTestDate, knownRecallIDs: [],
                                     lastRefreshed: nil, pinnedAt: .now)) {}
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        case .tryIt:
            OnboardingPage(
                title: "עכשיו אתם",
                message: "הקלידו מספר רישוי של רכב כלשהו, שלכם או של רכב שאתם שוקלים לקנות."
            ) {
                VStack(spacing: Theme.Spacing.l) {
                    PlateField(text: $plate)
                    if plate.isEmpty {
                        Button {
                            plate = Onboarding.examplePlate
                        } label: {
                            Text("אין מספר בראש? נסו \(PlateFormat.dashed(Onboarding.examplePlate))")
                                .font(Theme.Typography.bodyBold)
                        }
                    }
                }
            }
        }
    }

    /// A test date 45 days out, so the sample card shows the "expiring soon" state.
    private static var sampleTestDate: String {
        let date = Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.m) {
            switch step {
            case .tryIt:
                Button("הצגת הרכב") {
                    onFinish(plate)
                }
                .buttonStyle(PlateKeyButtonStyle())
                .disabled(!plateIsValid)

                Button("אחר כך") { onFinish(nil) }
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(minHeight: 44)
            default:
                Button(step == .welcome ? "בואו נתחיל" : "המשך") {
                    if let next = Step(rawValue: step.rawValue + 1) { go(to: next) }
                }
                .buttonStyle(PlateKeyButtonStyle())
            }
        }
        .onChange(of: plate) { _, value in
            let digits = String(value.filter(\.isNumber).prefix(8))
            if digits != value { plate = digits }
        }
    }
}

// MARK: - Page scaffold

/// One guide screen: the visual on top, then a title and a short message.
private struct OnboardingPage<Visual: View>: View {
    let title: String
    let message: String
    @ViewBuilder var visual: () -> Visual

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                visual()
                    .frame(maxWidth: .infinity, minHeight: 220)

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text(title)
                        .font(.system(.largeTitle, weight: .heavy))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.system(.title3))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Progress bar

/// A thick plate-yellow bar with a dark rim that fills as the guide advances.
private struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.neutral.opacity(0.22))
                Capsule()
                    .fill(Theme.Colors.plateYellow)
                    .overlay(Capsule().strokeBorder(Theme.Colors.plateBorder, lineWidth: 2))
                    .frame(width: max(geo.size.height, geo.size.width * progress))
            }
        }
        .frame(height: 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - Visuals

/// The welcome plate: its number rolls through a few real plates.
private struct RollingPlate: View {
    private let plates = ["5970065", "3256880", "77720101", "9441873"]
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PlateChrome(stripWidth: 40, cornerRadius: 14, rim: 3) {
            Text(PlateFormat.dashed(plates[index]))
                .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Colors.textOnPlate)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.xl)
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardShadow()
        .rotationEffect(.degrees(-3))
        .padding(.horizontal, Theme.Spacing.s)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.snappy(duration: 0.5)) {
                    index = (index + 1) % plates.count
                }
            }
        }
    }
}

/// The report's contents arriving one after another: the guide's single
/// orchestrated reveal.
private struct HighlightsReveal: View {
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(Array(ReportHighlight.all.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: item.systemImage)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 32)
                    Text(item.title)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(Theme.Colors.success)
                }
                .padding(Theme.Spacing.l)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                        .fill(Theme.Colors.surface)
                )
                .opacity(index < shown ? 1 : 0)
                .offset(y: index < shown ? 0 : 14)
            }
        }
        .accessibilityElement(children: .combine)
        .task {
            if reduceMotion {
                shown = ReportHighlight.all.count
                return
            }
            for count in 1...ReportHighlight.all.count {
                try? await Task.sleep(for: .milliseconds(count == 1 ? 250 : 180))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shown = count }
            }
        }
    }
}

/// A plate framed by camera viewfinder corners, with a sweeping scan line.
private struct ScanIllustration: View {
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PlateView(number: Onboarding.examplePlate)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, 44)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.Colors.primary)
                            .frame(height: 3)
                            .padding(.horizontal, Theme.Spacing.m)
                            .offset(y: sweep ? geo.size.height - 28 : 25)
                    }
                }
            }
            .overlay { ViewfinderCorners().stroke(Theme.Colors.textPrimary,
                                                  style: StrokeStyle(lineWidth: 5, lineCap: .round,
                                                                     lineJoin: .round)) }
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    sweep = true
                }
            }
    }
}

private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm: CGFloat = 30
        let r: CGFloat = 14
        var p = Path()
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        return p
    }
}

#Preview {
    OnboardingView { _ in }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}
