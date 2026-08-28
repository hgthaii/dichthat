import AppKit
import DichThatCore

@MainActor
enum ScreenGeometryResolver {
    struct Resolution {
        let screen: NSScreen
        let mainDisplayHeight: Double
    }

    static func resolve(anchor: SelectionAnchor) -> Resolution? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let primary = screens.first(where: {
            abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5
        }) ?? screens[0]
        let mainDisplayHeight = primary.frame.height
        let frames = screens.map {
            CaptureBounds(
                x: $0.frame.minX,
                y: $0.frame.minY,
                width: $0.frame.width,
                height: $0.frame.height
            )
        }
        let index = TranslationPopupGeometry.screenIndex(
            anchor: anchor,
            mainDisplayHeight: mainDisplayHeight,
            screenFrames: frames
        )
        guard let index, screens.indices.contains(index) else { return nil }
        return Resolution(screen: screens[index], mainDisplayHeight: mainDisplayHeight)
    }
}
