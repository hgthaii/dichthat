import Testing
@testable import DichThatCore

@Test("Version comparison handles tags and missing trailing components")
func versionComparison() throws {
    #expect(try #require(VersionNumber("v0.2.0")) > #require(VersionNumber("0.1.9")))
    #expect(try #require(VersionNumber("1.0")) == #require(VersionNumber("1.0.0")))
    #expect(VersionNumber("release") == nil)
}
