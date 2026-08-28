import DichThatCore
import Testing

@Test func convertsARPABETToUSIPA() {
    #expect(ARPABETConverter.ipa(from: "W ER1 D") == "/wɝd/")
    #expect(ARPABETConverter.ipa(from: "AH0 B AW1 T") == "/əˈbaʊt/")
    #expect(ARPABETConverter.ipa(from: "T R AE2 N S L EY1 SH AH0 N") == "/ˌtɹænsˈleɪʃən/")
}

@Test func rejectsUnknownARPABETSymbols() {
    #expect(ARPABETConverter.ipa(from: "") == nil)
    #expect(ARPABETConverter.ipa(from: "NOPE1") == nil)
}
