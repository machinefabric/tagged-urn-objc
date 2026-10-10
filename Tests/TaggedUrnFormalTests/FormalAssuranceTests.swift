import TaggedUrnFormal
import XCTest

final class FormalAssuranceTests: XCTestCase {
    // TEST0600: every function of the proved model this mirror calls carries a proved claim.
    //
    // The model's package carries what is proved of each function it exports (its assurance
    // document, generated from ../formal): each one decides, equals or keeps what its claim says,
    // and none rests on an assumption about the host — the model needs none.
    func test0600_EveryModelFunctionCarriesAProvedClaim() throws {
        let a = assurance
        XCTAssertTrue(a.facilities.isEmpty && a.assumptions.isEmpty, "the model assumes nothing of the host")
        XCTAssertFalse(a.exports.isEmpty)
        for e in a.exports {
            XCTAssertFalse(e.claims.isEmpty, "\(e.name) carries no claim")
            XCTAssertTrue(e.assumptions.isEmpty, "\(e.name) rests on \(e.assumptions)")
            for name in e.claims {
                let claim = try XCTUnwrap(a.claim(name), name)
                XCTAssertEqual(claim.status, "proved", name)
                XCTAssertTrue(claim.subjects.contains(e.name), "\(name) is about \(e.name)")
            }
        }
        let refines = try XCTUnwrap(a.claim("TaggedUrn.Exec.refines_decides"))
        XCTAssertEqual(refines.relation, "lungo.decides")
        XCTAssertEqual(refines.specifications, ["TaggedUrn.refines"])
    }
}
