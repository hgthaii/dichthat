import Testing
@testable import DichThatCore

@Test("Granted status menu starts with Check for Updates")
func statusMenuIsExact() {
    #expect(StatusMenuModel.items(accessibilityGranted: true, language: .english) == [
        StatusMenuItemModel(title: "Check for Updates…", action: .checkForUpdates),
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit DichThat", action: .quit),
    ])
}

@Test("Missing accessibility adds a temporary grant action")
func accessibilityGrantActionIsConditional() {
    let normal = StatusMenuModel.buttonPresentation(
        accessibilityGranted: true,
        language: .english
    )
    let warning = StatusMenuModel.buttonPresentation(
        accessibilityGranted: false,
        language: .english
    )

    #expect(normal.imageKind == .brandTemplate)
    #expect(normal.toolTip == "DichThat")
    #expect(warning.imageKind == .brandTemplate)
    #expect(warning.toolTip.contains("Accessibility permission required"))
    #expect(warning.accessibilityLabel == warning.toolTip)
    #expect(StatusMenuModel.items(accessibilityGranted: true, language: .english).count == 3)
    #expect(StatusMenuModel.items(accessibilityGranted: false, language: .english) == [
        StatusMenuItemModel(
            title: "Grant Accessibility Access…",
            action: .grantAccessibility
        ),
        StatusMenuItemModel(title: "Check for Updates…", action: .checkForUpdates),
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit DichThat", action: .quit),
    ])
}

@Test("Status menu supports Vietnamese")
func statusMenuSupportsVietnamese() {
    #expect(StatusMenuModel.items(accessibilityGranted: false, language: .vietnamese) == [
        StatusMenuItemModel(title: "Cấp quyền Trợ năng…", action: .grantAccessibility),
        StatusMenuItemModel(title: "Kiểm tra bản cập nhật…", action: .checkForUpdates),
        StatusMenuItemModel(title: "Cài đặt…", action: .settings),
        StatusMenuItemModel(title: "Thoát DichThat", action: .quit),
    ])
}

@Test("Missing translation models keep only Settings and Quit available")
func missingTranslationModelsLockStatusMenu() {
    #expect(StatusMenuModel.items(
        accessibilityGranted: false,
        translationLanguagesReady: false,
        language: .english
    ) == [
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit DichThat", action: .quit),
    ])
}
