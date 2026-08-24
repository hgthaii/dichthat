import Testing
@testable import DichThatCore

@Test("Status menu contains exactly Settings then Quit")
func statusMenuIsExact() {
    #expect(StatusMenuModel.items == [
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit Dịch Thật", action: .quit),
    ])
}

@Test("Accessibility warning changes button metadata and not menu")
func accessibilityWarningIsStatusButtonOnly() {
    let normal = StatusMenuModel.buttonPresentation(accessibilityGranted: true)
    let warning = StatusMenuModel.buttonPresentation(accessibilityGranted: false)

    #expect(normal.imageKind == .brandTemplate)
    #expect(normal.toolTip == "Dịch Thật")
    #expect(warning.imageKind == .accessibilityWarning)
    #expect(warning.toolTip.contains("Accessibility permission required"))
    #expect(warning.accessibilityLabel == warning.toolTip)
    #expect(StatusMenuModel.items.count == 2)
    #expect(!StatusMenuModel.items.contains { $0.title.contains("Accessibility") })
}
