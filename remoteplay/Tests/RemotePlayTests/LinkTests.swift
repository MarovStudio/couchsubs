// SPDX-License-Identifier: AGPL-3.0-only

import CChiaki
import XCTest

final class LinkTests: XCTestCase {
    func testChiakiLibraryIsLinked() {
        XCTAssertEqual(String(cString: chiaki_rp_version_string(CHIAKI_TARGET_PS5_1)), "1.0")
    }
}
