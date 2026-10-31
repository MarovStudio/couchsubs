// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import RemotePlay

final class PSNAccountTests: XCTestCase {
    func testCodeIsReadFromRedirect() {
        let url = URL(string: PSNAccount.redirectPrefix + "?code=AbC123&cid=x")!
        XCTAssertEqual(PSNAccount.code(fromRedirect: url), "AbC123")
    }

    func testNonRedirectUrlHasNoCode() {
        XCTAssertNil(PSNAccount.code(fromRedirect: URL(string: "https://example.com/redirect?code=AbC123")!))
    }

    func testUserIdBecomesEightLittleEndianBytes() {
        XCTAssertEqual(PSNAccount.accountIdBytes(userId: "1")?.base64EncodedString(), "AQAAAAAAAAA=")
        XCTAssertEqual(PSNAccount.accountIdBytes(userId: "258")?.map { $0 }, [2, 1, 0, 0, 0, 0, 0, 0])
    }

    func testInvalidUserIdIsRejected() {
        XCTAssertNil(PSNAccount.accountIdBytes(userId: "abc"))
        XCTAssertNil(PSNAccount.accountIdBytes(userId: ""))
    }

    func testAuthorizeUrlPointsToSonyWithRemotePlayRedirect() {
        let url = PSNAccount.authorizeURL.absoluteString
        XCTAssertTrue(url.hasPrefix("https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/authorize?"))
        XCTAssertTrue(url.contains("redirect_uri=https://remoteplay.dl.playstation.net/remoteplay/redirect"))
    }
}
