import Foundation

/// Reads the package's String Catalog in an explicitly requested locale.
///
/// Two problems make this type necessary rather than calling Foundation
/// directly:
///
/// 1. `LocalizedStringResource(_:locale:bundle:)` paired with
///    `String(localized:)` resolves against the *process* locale rather than
///    the locale carried by the resource, so an `es`/`vi` request silently
///    returned the English entry.
/// 2. Only Xcode's build system compiles `Localizable.xcstrings` into
///    per-language `.lproj` bundles. Command-line SwiftPM copies the catalog
///    through verbatim, so `swift test` had no localization data at all and
///    could never verify the pinned translations.
///
/// So lookup tries the compiled `.lproj` bundle first (the normal path in a
/// packaged app) and falls back to parsing the shipped `.xcstrings` directly
/// (the path under SwiftPM). `Localizable.xcstrings` stays the single source
/// of truth either way, and the doctrine-pinned hedge templates in
/// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md are verifiable
/// by the package's own test suite instead of only inside Xcode.
enum LocalizedCatalog {
    /// Returns the catalog entry for `key` rendered in `locale`.
    ///
    /// Falls back to the development language (`en`) when `locale` has no
    /// translation. Catalog keys *are* their English source strings, so a
    /// missing entry degrades to an English hedge rather than to a raw
    /// identifier or — the outcome that would actually matter — an unhedged
    /// assertion.
    static func string(_ key: String, locale: Locale) -> String {
        compiledString(key, locale: locale) ?? catalogString(key, locale: locale) ?? key
    }

    // MARK: - Compiled `.lproj` lookup (Xcode-built bundles)

    /// Looks `key` up in the compiled `.lproj` bundle for `locale`, returning
    /// `nil` when either the bundle or the key is absent so the caller can
    /// fall through to the raw catalog.
    private static func compiledString(_ key: String, locale: Locale) -> String? {
        guard let bundle = localizedBundle(for: locale) else { return nil }
        // `localizedString` echoes `value` when a key is missing; a sentinel is
        // the only way to tell "absent" from "translated to something".
        let sentinel = "\u{0}__sensebridge_missing__"
        let value = bundle.localizedString(forKey: key, value: sentinel, table: nil)
        return value == sentinel ? nil : value
    }

    /// The `.lproj` bundle matching `locale`, or `nil` when this build system
    /// did not produce one.
    private static func localizedBundle(for locale: Locale) -> Bundle? {
        for code in languageCandidates(for: locale) {
            // Kept as two single-line conditions: SwiftFormat's
            // `wrapMultilineStatementBraces` and SwiftLint's `opening_brace`
            // disagree about where a multi-line condition's brace belongs.
            guard let path = Bundle.module.path(forResource: code, ofType: "lproj") else {
                continue
            }
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    // MARK: - Raw `.xcstrings` lookup (SwiftPM-built bundles)

    /// The shipped String Catalog, parsed once. `nil` when the resource is
    /// missing or malformed, which leaves callers on the English fallback.
    private static let catalog: StringCatalog? = {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StringCatalog.self, from: data)
    }()

    /// Looks `key` up directly in the parsed catalog.
    private static func catalogString(_ key: String, locale: Locale) -> String? {
        guard let entry = catalog?.strings[key] else { return nil }
        for code in languageCandidates(for: locale) {
            if let value = entry.localizations[code]?.stringUnit?.value {
                return value
            }
        }
        return nil
    }

    /// Locale identifiers to try, most specific first: the full identifier (so
    /// a future `es_MX` entry would win over `es`), then the bare language
    /// code. Order is load-bearing, and the two collapse to one entry when the
    /// locale carries no region.
    private static func languageCandidates(for locale: Locale) -> [String] {
        let identifier = locale.identifier
        guard let code = locale.language.languageCode?.identifier, code != identifier else {
            return [identifier]
        }
        return [identifier, code]
    }
}

/// The subset of Apple's String Catalog format this package reads. Only the
/// fields needed for a locale lookup are modeled; everything else in the
/// format (extraction state, plural variations, comments) is ignored.
private struct StringCatalog: Decodable, Sendable {
    /// The development language, used as the implicit fallback.
    let sourceLanguage: String

    /// Catalog entries keyed by their source string.
    let strings: [String: CatalogEntry]
}

/// One catalog key and its per-language translations.
private struct CatalogEntry: Decodable, Sendable {
    /// Translations keyed by language code. The catalog omits this field
    /// entirely for keys that exist only in the source language, which decodes
    /// to an empty dictionary rather than an absent one.
    let localizations: [String: CatalogLocalization]

    private enum CodingKeys: String, CodingKey {
        case localizations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localizations = try container.decodeIfPresent(
            [String: CatalogLocalization].self,
            forKey: .localizations
        ) ?? [:]
    }
}

/// One language's translation of a catalog key.
private struct CatalogLocalization: Decodable, Sendable {
    /// The translated text, absent for entries that carry only metadata.
    let stringUnit: CatalogStringUnit?
}

/// The translated text itself.
private struct CatalogStringUnit: Decodable, Sendable {
    let value: String
}
