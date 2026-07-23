import XCTest

/// Covers the in-app language picker (`SettingsView`) and the OS-level
/// per-app language mechanism it depends on — see
/// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md "Unit B".
@MainActor
final class LanguageSelectionUITests: XCTestCase {
    /// Happy path: picking Spanish in Settings updates the Home screen's
    /// visible labels immediately, no relaunch required.
    func testPickingSpanishUpdatesHomeScreenLabels() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        selectLanguage("Español", in: app)
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.navigationBars["SenseBridge"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, labeled: "Leer documento").waitForExistence(timeout: 5))
    }

    /// Edge case: with the in-app picker left at its `.system` default, the
    /// OS-level per-app language (set here via an `-AppleLanguages` launch
    /// override, standing in for iOS Settings > App > Language) drives the
    /// UI independent of the picker.
    func testSystemLanguageOverrideRendersVietnamese() {
        continueAfterFailure = false
        let setup = XCUIApplication()
        setup.launchArguments = ["-uiTestReset"]
        setup.launch()
        selectLanguage("System", in: setup)
        setup.terminate()

        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()

        XCTAssertTrue(element(app, labeled: "Đọc tài liệu").waitForExistence(timeout: 5))
    }

    /// Edge case: a picked language persists across a relaunch instead of
    /// reverting to `.system`.
    func testPickedLanguagePersistsAcrossRelaunch() {
        continueAfterFailure = false
        let setup = XCUIApplication()
        setup.launchArguments = ["-uiTestReset"]
        setup.launch()
        selectLanguage("Tiếng Việt", in: setup)
        setup.terminate()

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(element(app, labeled: "Đọc tài liệu").waitForExistence(timeout: 5))
    }

    /// Navigates from Home into Settings and picks `option` from the
    /// language menu.
    private func selectLanguage(_ option: String, in app: XCUIApplication) {
        element(app, labeled: "Settings").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Language")).firstMatch.tap()
        app.buttons[option].tap()
    }

    private func element(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
