public enum SelectionTargetResolver {
    public static func targetPID(
        frontmostPID: Int32?,
        ownPID: Int32,
        lastExternalPID: Int32?
    ) -> Int32? {
        guard frontmostPID == ownPID else { return frontmostPID }
        return lastExternalPID
    }
}
