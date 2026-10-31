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
    var failuresLeft = 0
    func translate(_ text: String) async throws -> String {
        if let error { throw error }
        if failuresLeft > 0 { failuresLeft -= 1; throw URLError(.timedOut) }
        return "TR: " + text
    }
}

/// Çevirileri test kapıyı açana kadar bekletir; kapı açıldıktan sonra gelenler beklemez.
private final class GatedTranslator: TextTranslator {
    private(set) var requested: [String] = []
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func translate(_ text: String) async throws -> String {
        requested.append(text)
        if !isOpen { await withCheckedContinuation { waiting.append($0) } }
        return "TR: " + text
    }
    func open() { isOpen = true; waiting.forEach { $0.resume() }; waiting.removeAll() }
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
        for _ in 0..<3 { await pipeline.process(frame, region: CropRegion()); await pipeline.translation?.value }
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
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()); await pipeline.translation?.value }
        XCTAssertTrue(sender.sent.isEmpty)
        XCTAssertEqual(pipeline.lastError, .needsDownload)
    }

    func testFailedTranslationIsRetriedWhileLineStaysOnScreen() async {
        let sender = FakeSender()
        let translator = FakeTranslator()
        translator.failuresLeft = 1
        let pipeline = SubtitlePipeline(reader: FakeReader(Array(repeating: "Hold the gate", count: 4)), translator: translator, server: sender)
        for _ in 0..<4 { await pipeline.process(frame, region: CropRegion()); await pipeline.translation?.value }
        XCTAssertEqual(sender.sent, ["TR: Hold the gate"])
    }

    /// Kareler saniyede ~10 kez okunur; tek tük okunamayan kare altyazıyı TV'den silmemeli.
    func testShortReadingGapDoesNotClearTheTV() async {
        let sender = FakeSender()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "", "", "Hold the gate"]),
                                        translator: FakeTranslator(), server: sender)
        for _ in 0..<5 { await pipeline.process(frame, region: CropRegion()); await pipeline.translation?.value }
        XCTAssertEqual(sender.clears, 0)
        XCTAssertEqual(sender.sent, ["TR: Hold the gate"])
    }

    func testSubtitleGoneForFourFramesClearsTheTV() async {
        let sender = FakeSender()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "", "", "", ""]),
                                        translator: FakeTranslator(), server: sender)
        for _ in 0..<6 { await pipeline.process(frame, region: CropRegion()); await pipeline.translation?.value }
        XCTAssertEqual(sender.clears, 1)
    }

    /// Çeviri sürerken okuma durmamalı; yoksa kısa satırlar kaçar.
    func testReadingContinuesWhileTranslating() async {
        let reader = FakeReader(["Hold the gate", "Hold the gate", "Run", "Run"])
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: reader, translator: translator, server: FakeSender())
        // İlk satırın çevirisi kapıda beklerken ikinci satır okunup çeviriye gönderilmiş olmalı.
        for _ in 0..<4 { await pipeline.process(frame, region: CropRegion()) }
        translator.open()
        await pipeline.translation?.value
        XCTAssertEqual(translator.requested, ["Hold the gate", "Run"])
    }

    /// Yeni satır çevrilmeye başladıysa eski satırın geç gelen çevirisi gösterilmez.
    func testLateTranslationOfOldLineIsDropped() async {
        let sender = FakeSender()
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "Run", "Run"]),
                                        translator: translator, server: sender)
        for _ in 0..<4 { await pipeline.process(frame, region: CropRegion()) }
        translator.open()
        await pipeline.translation?.value
        XCTAssertEqual(sender.sent, ["TR: Run"])
    }

    /// Satır ekrandan kalktıktan sonra gelen çevirisi TV'ye gönderilmez.
    func testTranslationArrivingAfterClearIsDropped() async {
        let sender = FakeSender()
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate"]), translator: translator, server: sender)
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()) }
        pipeline.reset()
        translator.open()
        await pipeline.translation?.value
        XCTAssertTrue(sender.sent.isEmpty)
    }

    func testShortLinesGetAZoomedSecondReading() throws {
        let image = frame
        var tried: [Int] = []
        let text = try VisionReader.firstReading(of: image) { candidate in
            tried.append(candidate.width)
            // Yalnız ortası büyütülmüş görüntüde okunabilen kısa satır.
            return candidate.width == Int((Double(image.width) * 0.4).rounded()) * 2 ? "Go!" : ""
        }
        XCTAssertEqual(text, "Go!")
        XCTAssertEqual(tried, [64, 52])
    }

    func testFullReadingIsUsedWhenItFindsText() throws {
        var calls = 0
        let text = try VisionReader.firstReading(of: frame) { _ in calls += 1; return "Hold the gate" }
        XCTAssertEqual(text, "Hold the gate")
        XCTAssertEqual(calls, 1)
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
