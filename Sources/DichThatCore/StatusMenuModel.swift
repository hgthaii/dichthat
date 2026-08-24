public enum StatusMenuAction: Equatable, Sendable {
    case settings
    case quit
}

public struct StatusMenuItemModel: Equatable, Sendable {
    public let title: String
    public let action: StatusMenuAction

    public init(title: String, action: StatusMenuAction) {
        self.title = title
        self.action = action
    }
}

public enum StatusButtonImageKind: Equatable, Sendable {
    case brandTemplate
    case accessibilityWarning
}

public struct StatusButtonPresentation: Equatable, Sendable {
    public let imageKind: StatusButtonImageKind
    public let toolTip: String
    public let accessibilityLabel: String

    public init(
        imageKind: StatusButtonImageKind,
        toolTip: String,
        accessibilityLabel: String
    ) {
        self.imageKind = imageKind
        self.toolTip = toolTip
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum StatusMenuModel {
    public static let items = [
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit \(AppIdentity.productName)", action: .quit),
    ]

    public static func buttonPresentation(
        accessibilityGranted: Bool
    ) -> StatusButtonPresentation {
        if accessibilityGranted {
            return StatusButtonPresentation(
                imageKind: .brandTemplate,
                toolTip: AppIdentity.productName,
                accessibilityLabel: AppIdentity.productName
            )
        }
        let warning = "\(AppIdentity.productName) — Accessibility permission required"
        return StatusButtonPresentation(
            imageKind: .accessibilityWarning,
            toolTip: warning,
            accessibilityLabel: warning
        )
    }
}
