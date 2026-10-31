// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import RemotePlay

final class RegistrationReasonTests: XCTestCase {
    /// PS5'in red nedeni yalnız libchiaki günlüğünde gelir; oradan okunmalı.
    func testReasonIsReadFromChiakiLog() {
        XCTAssertEqual(Registration.reason(fromLog: "Reported Application Reason: 0x80108b02 (Invalid PSN ID)"), 0x80108b02)
        XCTAssertNil(Registration.reason(fromLog: "Regist waiting for response"))
    }

    func testInvalidPSNIdMeansWrongAccount() {
        XCTAssertEqual(Registration.RegistrationError(reason: 0x80108b02), .wrongAccount)
        XCTAssertEqual(Registration.RegistrationError(reason: 0x80108b09), .failed)
        XCTAssertEqual(Registration.RegistrationError(reason: nil), .failed)
    }
}
