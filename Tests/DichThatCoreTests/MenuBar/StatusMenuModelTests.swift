import Testing
@testable import DichThatCore

@Test("Granted status menu starts with Check for Updates")
func statusMenuIsExact() {
    #expect(StatusMenuModel.items == [
        StatusMenuItemModel(title: "Check for Updates…", action: .checkForUpdates),
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit DichThat", action: .quit),
    ])
}

@Test("Missing accessibility adds a temporary grant action")
func accessibilityGrantActionIsConditional() {
    let normal = StatusMenuModel.buttonPresentation(accessibilityGranted: true)
    let warning = StatusMenuModel.buttonPresentation(accessibilityGranted: false)

    #expect(normal.imageKind == .brandTemplate)
    #expect(normal.toolTip == "DichThat")
    #expect(warning.imageKind == .brandTemplate)
    #expect(warning.toolTip.contains("Accessibility permission required"))
    #expect(warning.accessibilityLabel == warning.toolTip)
    #expect(StatusMenuModel.items.count == 3)
    #expect(StatusMenuModel.items(accessibilityGranted: false) == [
        StatusMenuItemModel(
            title: "Grant Accessibility Access…",
            action: .grantAccessibility
        ),
        StatusMenuItemModel(title: "Check for Updates…", action: .checkForUpdates),
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit DichThat", action: .quit),
    ])
}
