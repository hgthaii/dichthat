public enum SelectionAnchorResolver {
    public static func resolve(
        captured: SelectionAnchor,
        observed: SelectionAnchor?
    ) -> SelectionAnchor {
        // An observed anchor belongs to the actual selection gesture. It is more
        // trustworthy for placement than a later AX range lookup, because some
        // web views return range rectangles in a local coordinate space while
        // still reporting the selected text correctly.
        observed ?? captured
    }
}
