import Testing
@testable import DichThatCore

@Test("Application identity is stable")
func applicationIdentityIsStable() {
    #expect(AppIdentity.productName == "DichThat")
    #expect(AppIdentity.executableName == "DichThat")
    #expect(AppIdentity.bundleIdentifier == "dev.hgthaii.dichthat")
    #expect(AppIdentity.minimumSystemVersion == "13.0")
    #expect(AppIdentity.currentVersion == "0.1.0")
}
