public enum StatusMenuAction: Equatable, Sendable {
    case grantAccessibility
    case checkForUpdates
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
    public static var items: [StatusMenuItemModel] {
        items(accessibilityGranted: true)
    }

    public static func items(accessibilityGranted: Bool) -> [StatusMenuItemModel] {
        var result: [StatusMenuItemModel] = []
        if !accessibilityGranted {
            result.append(StatusMenuItemModel(
                title: AppText.Menu.grantAccessibility,
                action: .grantAccessibility
            ))
        }
        result.append(StatusMenuItemModel(
            title: AppText.Menu.checkForUpdates,
            action: .checkForUpdates
        ))
        result.append(StatusMenuItemModel(title: AppText.Menu.settings, action: .settings))
        result.append(StatusMenuItemModel(
            title: "\(AppText.Menu.quitPrefix) \(AppIdentity.productName)",
            action: .quit
        ))
        return result
    }

    public static func buttonPresentation(
        accessibilityGranted: Bool
    ) -> StatusButtonPresentation {
        let label = accessibilityGranted
            ? AppIdentity.productName
            : "\(AppIdentity.productName) — \(AppText.Menu.accessibilityRequiredSuffix)"
        return StatusButtonPresentation(
            imageKind: .brandTemplate,
            toolTip: label,
            accessibilityLabel: label
        )
    }
}
