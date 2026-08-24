import Testing
@testable import DichThatCore

@Test("Application identity is stable")
func applicationIdentityIsStable() {
    #expect(AppIdentity.productName == "Dịch Thật")
    #expect(AppIdentity.executableName == "DichThat")
    #expect(AppIdentity.bundleIdentifier == "dev.hgthaii.dichthat")
    #expect(AppIdentity.minimumSystemVersion == "13.0")
}
