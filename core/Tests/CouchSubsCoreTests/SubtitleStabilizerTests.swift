// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import CouchSubsCore

final class SubtitleStabilizerTests: XCTestCase {
    func testEmitsAfterTwoStableFrames() {
        var s = SubtitleStabilizer()
        XCTAssertEqual(s.feed("We do not have time."), .none)
        XCTAssertEqual(s.feed("We do not have time."), .translate("We do not have time."))
        XCTAssertEqual(s.feed("We do not have time."), .none)
    }

    func testOcrNoiseDoesNotReemit() {
        var s = SubtitleStabilizer()
        _ = s.feed("The gate will not hold"); _ = s.feed("The gate will not hold")
        XCTAssertEqual(s.feed("The gale will not hold"), .none)
        XCTAssertEqual(s.feed("The gale will not hold"), .none)
    }

    func testFlickeringHudDoesNotSpam() {
        var s = SubtitleStabilizer()
        var sent = 0
        for i in 0..<20 { if case .translate = s.feed(i % 2 == 0 ? "24 / 120" : "") { sent += 1 } }
        XCTAssertEqual(sent, 0)
    }

    func testTypewriterSendsCompletedLine() {
        var s = SubtitleStabilizer()
        _ = s.feed("We do"); _ = s.feed("We do not have")
        _ = s.feed("We do not have time for this, boy.")
        XCTAssertEqual(s.feed("We do not have time for this, boy."), .translate("We do not have time for this, boy."))
    }

    func testTwoEmptyFramesClearAfterSend() {
        var s = SubtitleStabilizer()
        _ = s.feed("Hello there"); _ = s.feed("Hello there")
        XCTAssertEqual(s.feed(""), .none)
        XCTAssertEqual(s.feed(""), .clear)
    }

    func testAlreadyTranslatedIsSkipped() {
        var s = SubtitleStabilizer()
        XCTAssertFalse(s.shouldSend(source: "Kullanıcı Ekle Oturum Açtı", translation: "Kullanıcı Ekle Oturum Açtı"))
        XCTAssertTrue(s.shouldSend(source: "Add user", translation: "Kullanıcı ekle"))
    }

    func testResetClearsOnlyAfterSomethingWasSent() {
        var s = SubtitleStabilizer()
        XCTAssertEqual(s.reset(), .none)
        _ = s.feed("Hello there"); _ = s.feed("Hello there")
        XCTAssertEqual(s.reset(), .clear)
        XCTAssertEqual(s.reset(), .none)
    }
}
