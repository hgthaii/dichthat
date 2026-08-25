public enum SelectionAnchorResolver {
    public static func resolve(
        captured: SelectionAnchor,
        observed: SelectionAnchor?
    ) -> SelectionAnchor {
        guard case .mouse = captured, let observed else { return captured }
        return observed
    }
}
