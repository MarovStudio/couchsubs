// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import CouchSubsCore

final class TextMatchTests: XCTestCase {
    func testNormalizeStripsPunctuationAndCase() {
        XCTAssertEqual(TextMatch.normalize("Kratos: We do NOT have time, boy."), "kratos we do not have time boy")
    }

    func testSimilarToleratesOcrNoise() {
        XCTAssertTrue(TextMatch.isSimilar("the gate will not hold", "the gale will not hold"))
    }

    func testDifferentLinesAreNotSimilar() {
        XCTAssertFalse(TextMatch.isSimilar("we do not have time", "the gate will not hold"))
    }

    func testEmptyIsNeverSimilarToText() {
        XCTAssertFalse(TextMatch.isSimilar("", "abc"))
    }
}
