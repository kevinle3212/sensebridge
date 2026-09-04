import SwiftUI

// Development-only footer showing when this copy of the app landed on the
// device, so a stale install announces itself instead of masquerading as
// current code.
//
// The date is the app bundle's *creation* attribute — iOS writes a fresh
// bundle on every `npm run app:install` — not a compile timestamp, which
// build caching would freeze at whatever moment the module was first built.
// Compiled only in DEBUG (`SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`);
// release archives carry no watermark at all.
//
// Hidden from VoiceOver and hit-testing on purpose: it is build metadata,
// and an element that sits on every screen while doing nothing would pollute
// exactly the navigation this app's users depend on. Rendered as a second
// `safeAreaInset` rather than an overlay so it can never cover captions or
// controls — see `CaptionOverlay`, which owns the inset above this one.
#if DEBUG
    struct DevWatermarkFooter: View {
        var body: some View {
            if let installed = Self.lastDownloadedDate(at: Bundle.main.bundlePath) {
                Text("Last Downloaded: \(Self.formatted(installed))")
                    // `.system(.caption2, design: .monospaced)` keeps the text
                    // style's Dynamic Type scaling, which `.caption2.monospaced()`
                    // drops — the accessibility audit flags the latter as
                    // "Dynamic Type font sizes are partially unsupported".
                    .font(.system(.caption2, design: .monospaced))
                    // `.primary`, not `.secondary`: even this debug-only footer
                    // is on screen, and `.secondary` on `.bar` fails the WCAG-AA
                    // contrast audit that gates every screen.
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(.bar)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }

        /// The moment this bundle was written to disk — install time on device.
        ///
        /// `nil` when the attributes are unreadable, which simply hides the
        /// footer: cosmetic metadata must never become a crash path.
        static func lastDownloadedDate(at path: String) -> Date? {
            try? FileManager.default.attributesOfItem(atPath: path)[.creationDate] as? Date
        }

        /// Fixed numeric format rather than locale-aware: the audience is the
        /// developer comparing this against Xcode logs, and `en_US_POSIX` pins the
        /// output against both the user's 12/24-hour setting and any future
        /// localization of `DateFormatter`.
        static func formatted(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
#endif
