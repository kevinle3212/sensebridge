import SenseBridgeCore
import SwiftUI

/// Lets the user override the app's display language, or defer to the
/// device's system language via `.system` (the default) — see
/// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md.
struct SettingsView: View {
    /// Shared app state, read here for the current language and written
    /// back via `save()` when the user changes it.
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Form {
            Picker("Language", selection: languageBinding) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(displayName(for: language))
                        .tag(language)
                }
            }
            .accessibilityHint("Choose the app's display language.")
        }
        .navigationTitle("Settings")
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { environment.settings.language },
            set: { newValue in
                environment.settings.language = newValue
                environment.save()
            }
        )
    }

    /// Localized label shown in the language picker for `language`.
    private func displayName(for language: AppLanguage) -> LocalizedStringKey {
        switch language {
        case .system: "System"
        case .en: "English"
        case .es: "Español"
        case .vi: "Tiếng Việt"
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment())
}
