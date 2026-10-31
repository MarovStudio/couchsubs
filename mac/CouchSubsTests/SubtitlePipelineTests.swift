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
    private var waiting: [(text: String, continuation: CheckedContinuation<Void, Never>)] = []
    func translate(_ text: String) async throws -> String {
        requested.append(text)
        if !isOpen { await withCheckedContinuation { waiting.append((text, $0)) } }
        return "TR: " + text
    }
    func open() { isOpen = true; waiting.forEach { $0.continuation.resume() }; waiting.removeAll() }
    /// Yalnız bu satırın çevirisini bitirir (sırayı test belirler).
    func release(_ text: String) async {
        while !waiting.contains(where: { $0.text == text }) { await Task.yield() }
        let index = waiting.firstIndex { $0.text == text }!
        waiting.remove(at: index).continuation.resume()
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private final class FakeSender: SubtitleSending {
    var sent: [String] = []
    var durations: [Int] = []
    var clears = 0
    func sendSubtitle(_ text: String, durationMs: Int) { sent.append(text); durations.append(durationMs) }
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
        for _ in 0..<3 { await pipeline.process(frame, region: CropRegion()); await pipeline.waitForTranslations() }
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
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()); await pipeline.waitForTranslations() }
        XCTAssertTrue(sender.sent.isEmpty)
        XCTAssertEqual(pipeline.lastError, .needsDownload)
    }

    func testFailedTranslationIsRetriedWhileLineStaysOnScreen() async {
        let sender = FakeSender()
        let translator = FakeTranslator()
        translator.failuresLeft = 1
        let pipeline = SubtitlePipeline(reader: FakeReader(Array(repeating: "Hold the gate", count: 4)), translator: translator, server: sender)
        for _ in 0..<4 { await pipeline.process(frame, region: CropRegion()); await pipeline.waitForTranslations() }
        XCTAssertEqual(sender.sent, ["TR: Hold the gate"])
    }

    /// Kareler saniyede ~10 kez okunur; tek tük okunamayan kare altyazıyı TV'den silmemeli.
    func testShortReadingGapDoesNotClearTheTV() async {
        let sender = FakeSender()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "", "", "Hold the gate"]),
                                        translator: FakeTranslator(), server: sender)
        for _ in 0..<5 { await pipeline.process(frame, region: CropRegion()); await pipeline.waitForTranslations() }
        XCTAssertEqual(sender.clears, 0)
        XCTAssertEqual(sender.sent, ["TR: Hold the gate"])
    }

    func testSubtitleGoneForFourFramesClearsTheTV() async {
        let sender = FakeSender()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate", "", "", "", ""]),
                                        translator: FakeTranslator(), server: sender)
        for _ in 0..<6 { await pipeline.process(frame, region: CropRegion()); await pipeline.waitForTranslations() }
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
        await pipeline.waitForTranslations()
        XCTAssertEqual(translator.requested, ["Hold the gate", "Run"])
    }

    /// Hızlı konuşmada yeni satır gelse de önceki satırın çevirisi gösterilir; satır kaybolmaz.
    func testEarlierLineIsShownWhenItsTranslationArrivesFirst() async {
        let sender = FakeSender()
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate.", "Run!"]), translator: translator, server: sender)
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()) }
        await translator.release("Hold the gate.")
        await translator.release("Run!")
        await pipeline.waitForTranslations()
        XCTAssertEqual(sender.sent, ["TR: Hold the gate.", "TR: Run!"])
    }

    /// Yeni satırın çevirisi zaten gösterildiyse eski satırınki onun üstüne yazılmaz.
    func testOlderTranslationArrivingAfterNewerIsDropped() async {
        let sender = FakeSender()
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate.", "Run!"]), translator: translator, server: sender)
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()) }
        await translator.release("Run!")
        await translator.release("Hold the gate.")
        await pipeline.waitForTranslations()
        XCTAssertEqual(sender.sent, ["TR: Run!"])
    }

    /// Satır ekrandan kalktıktan sonra çevirisi gelirse yine de okunacak kadar kısa süre gösterilir.
    func testTranslationArrivingAfterLineLeftIsShownBriefly() async {
        let sender = FakeSender()
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate.", "", "", "", ""]), translator: translator, server: sender)
        for _ in 0..<5 { await pipeline.process(frame, region: CropRegion()) }
        XCTAssertEqual(sender.clears, 1)
        translator.open()
        await pipeline.waitForTranslations()
        XCTAssertEqual(sender.sent, ["TR: Hold the gate."])
        XCTAssertEqual(sender.durations.first ?? 0, 2000 + "TR: Hold the gate.".count * 60)
    }

    /// Çeviri durdurulduysa geç gelen çeviri TV'ye gönderilmez.
    func testTranslationArrivingAfterStopIsDropped() async {
        let sender = FakeSender()
        let translator = GatedTranslator()
        let pipeline = SubtitlePipeline(reader: FakeReader(["Hold the gate", "Hold the gate"]), translator: translator, server: sender)
        for _ in 0..<2 { await pipeline.process(frame, region: CropRegion()) }
        pipeline.reset()
        translator.open()
        await pipeline.waitForTranslations()
        XCTAssertTrue(sender.sent.isEmpty)
    }

    func testShortLinesGetAZoomedSecondReading() throws {
        let image = frame
        let stripWidth = Int((Double(image.width) * 0.4).rounded()) * 2
        let text = try VisionReader.firstReading(of: image) { candidate in
            // Yalnız ortası büyütülmüş görüntüde okunabilen kısa satır.
            candidate.width == stripWidth ? "Go!" : ""
        }
        XCTAssertEqual(text, "Go!")
    }

    /// İki yedek okuma da yazı bulursa ortadaki şeridinki (daha güvenilir olanı) seçilir.
    func testCenterStripReadingWinsOverZoomedRegion() throws {
        let image = frame
        let text = try VisionReader.firstReading(of: image) { candidate in
            switch candidate.width {
            case image.width: ""
            case image.width * 2: "G0!"
            default: "Go!"
            }
        }
        XCTAssertEqual(text, "Go!")
    }

    func testFullReadingIsUsedWhenItFindsText() throws {
        let calls = Counter()
        let text = try VisionReader.firstReading(of: frame) { _ in calls.increment(); return "Hold the gate" }
        XCTAssertEqual(text, "Hold the gate")
        XCTAssertEqual(calls.value, 1)
    }

    /// Bölge boşken iki yedek okuma art arda değil aynı anda yapılır; yeni satır daha erken fark edilir.
    func testFallbackReadingsRunAtTheSameTime() throws {
        let image = frame
        let start = Date()
        _ = try VisionReader.firstReading(of: image) { candidate in
            if candidate.width != image.width { Thread.sleep(forTimeInterval: 0.2) }
            return ""
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.35)
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
