// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import ImageIO
import XCTest
@testable import CouchSubs

private final class FakeReader: TextReader, @unchecked Sendable {
    var texts: [String]
    var readOnMainThread: [Bool] = []
    init(_ texts: [String]) { self.texts = texts }
    func read(_ image: CGImage) throws -> String {
        readOnMainThread.append(Thread.isMainThread)
        return texts.isEmpty ? "" : texts.removeFirst()
    }
}

private final class FakeTranslator: TextTranslator {
    var error: Error?
    func translate(_ text: String) async throws -> String {
        if let error { throw error }
        return "TR: " + text
    }
}

private final class FakeSender: SubtitleSending {
    var sent: [String] = []
    var clears = 0
    func sendSubtitle(_ text: String, durationMs: Int) { sent.append(text) }
    func clear() { clears += 1 }
}

@MainActor
final class SubtitlePipelineTests: XCTestCase {
    private let frame: CGImage = {
        let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }()

    func testStableTextIsTranslatedAndSentOnce() async {
        let sender = FakeSender()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "Hold the gate"]),
                                        translator: FakeTranslator(), server: sender)
        for _ in 0..<3 { await pipeline.process(frame, region: CropRegion()) }
        XCTAssertEqual(sender.sent, ["TR: Hold the gate"])
        XCTAssertEqual(pipeline.lastPair?.source, "Hold the gate")
    }

    func testTextRecognitionRunsOffTheMainThread() async {
        let reader = FakeReader(["Hold the gate"])
        let pipeline = SubtitlePipeline(reader: reader, translator: FakeTranslator(), server: FakeSender())
        await pipeline.process(frame, region: CropRegion())
        XCTAssertEqual(reader.readOnMainThread, [false])
    }

    func testMissingLanguagePackSendsNothing() async {
        let sender = FakeSender()
        let translator = FakeTranslator()
        translator.error = TranslatorError.needsDownload
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate"]), translator: translator, server: sender)
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()) }
        XCTAssertTrue(sender.sent.isEmpty)
        XCTAssertEqual(pipeline.lastError, .needsDownload)
    }

    func testTwoEmptyFramesClearTheTV() async {
        let sender = FakeSender()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "", ""]),
                                        translator: FakeTranslator(), server: sender)
        for _ in 0..<4 { await pipeline.process(frame, region: CropRegion()) }
        XCTAssertEqual(sender.clears, 1)
    }

    func testVisionReadsSubtitleButNotHud() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "oyun-karesi", withExtension: "png"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let text = try VisionReader().read(RegionCropper.crop(image, to: CropRegion(top: 0.6, bottom: 0.99)))
        XCTAssertTrue(text.contains("We do not have time for this, boy"), text)
        XCTAssertFalse(text.contains("24 / 120"), text)
    }
}
