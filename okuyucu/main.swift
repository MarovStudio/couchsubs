// Okuyucu: PS Remote Play penceresindeki altyazıyı okur (Vision OCR), cihaz üstünde
// Türkçeye çevirir (Apple Translation) ve altyazı sunucusuna gönderir.
//
// Kullanım:
//   ./okuyucu                          Remote Play penceresini izler
//   ./okuyucu --dosya resim.png        Tek bir görüntüyü okuyup çevirir (test)
// Seçenekler:
//   --uygulama "Remote Play"  izlenecek uygulamanın adı (içinde geçmesi yeterli)
//   --sunucu URL              altyazı sunucusu (varsayılan http://localhost:8787)
//   --bolge 0.62:0.97         okunacak dikey bölge (pencerenin üstünden oran olarak)
//   --yatay 0.14:0.86         okunacak yatay bölge (köşedeki HUD yazılarını dışarıda bırakır)
//   --fps 4                   saniyede kaç kare okunacağı
//   --kaynak en --hedef tr    çeviri dilleri
//   --onizleme kirpim.png     okunan son bölgeyi kaydeder (bölge ayarı için)

import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import Translation
import UniformTypeIdentifiers
import Vision

struct Ayarlar {
    var uygulama = "Remote Play"
    var sunucu = "http://localhost:8787"
    var bolgeUst = 0.62
    var bolgeAlt = 0.97
    var yataySol = 0.14
    var yataySag = 0.86
    var fps = 4.0
    var kaynak = "en"
    var hedef = "tr"
    var dosya: String?
    var onizleme: String?
}

func ayarlariOku() -> Ayarlar {
    var a = Ayarlar()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let bayrak = args.removeFirst()
        let deger = args.isEmpty ? "" : args.removeFirst()
        switch bayrak {
        case "--uygulama": a.uygulama = deger
        case "--sunucu": a.sunucu = deger
        case "--fps": a.fps = Double(deger) ?? a.fps
        case "--kaynak": a.kaynak = deger
        case "--hedef": a.hedef = deger
        case "--dosya": a.dosya = deger
        case "--onizleme": a.onizleme = deger
        case "--bolge":
            let p = deger.split(separator: ":").compactMap { Double($0) }
            if p.count == 2 { a.bolgeUst = p[0]; a.bolgeAlt = p[1] }
        case "--yatay":
            let p = deger.split(separator: ":").compactMap { Double($0) }
            if p.count == 2 { a.yataySol = p[0]; a.yataySag = p[1] }
        default:
            print("Bilinmeyen seçenek: \(bayrak)")
            exit(1)
        }
    }
    return a
}

// Çıktı bir dosyaya ya da sunucuya yönlendirildiğinde de satır satır görünsün.
setvbuf(stdout, nil, _IOLBF, 0)
// Komut satırı programında pencere sunucusu bağlantısını açar; yoksa ekran yakalama
// "CGS_REQUIRE_INIT" ile çöker.
_ = CGMainDisplayID()

let ayar = ayarlariOku()

// MARK: - Görüntü

func kirp(_ img: CGImage) -> CGImage {
    let w = Double(img.width), h = Double(img.height)
    let rect = CGRect(x: w * ayar.yataySol, y: h * ayar.bolgeUst,
                      width: w * (ayar.yataySag - ayar.yataySol), height: h * (ayar.bolgeAlt - ayar.bolgeUst))
    return img.cropping(to: rect.integral) ?? img
}

func kaydet(_ img: CGImage, _ yol: String) {
    guard let hedef = CGImageDestinationCreateWithURL(URL(fileURLWithPath: yol) as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(hedef, img, nil)
    CGImageDestinationFinalize(hedef)
}

func dosyadanYukle(_ yol: String) -> CGImage? {
    guard let kaynak = CGImageSourceCreateWithURL(URL(fileURLWithPath: yol) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(kaynak, 0, nil)
}

// MARK: - Metin tanıma

func metniOku(_ img: CGImage) throws -> String {
    let istek = VNRecognizeTextRequest()
    istek.recognitionLevel = .accurate
    istek.recognitionLanguages = [ayar.kaynak]
    istek.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: img).perform([istek])
    // Vision'ın kökeni sol alttadır; satırları yukarıdan aşağı sırala.
    return (istek.results ?? [])
        .compactMap { gozlem -> (CGFloat, String)? in
            guard let aday = gozlem.topCandidates(1).first, aday.confidence >= 0.5 else { return nil }
            return (gozlem.boundingBox.midY, aday.string)
        }
        .sorted { $0.0 > $1.0 }
        .map { $0.1 }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Karşılaştırma için sadeleştirilmiş metin: küçük harf, yalnız harf/rakam ve tek boşluk.
func sade(_ s: String) -> String {
    let harfler = s.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
    return String(harfler).split(separator: " ").joined(separator: " ")
}

/// OCR gürültüsünü tolere eden benzerlik (Levenshtein oranı).
func benzer(_ a: String, _ b: String, esik: Double = 0.85) -> Bool {
    if a == b { return true }
    let x = Array(a), y = Array(b)
    if x.isEmpty || y.isEmpty { return false }
    var onceki = Array(0...y.count)
    for i in 1...x.count {
        var satir = [i] + Array(repeating: 0, count: y.count)
        for j in 1...y.count {
            satir[j] = min(onceki[j] + 1, satir[j - 1] + 1, onceki[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
        }
        onceki = satir
    }
    return 1 - Double(onceki[y.count]) / Double(max(x.count, y.count)) >= esik
}

// MARK: - Çeviri

let cevirmen = TranslationSession(
    installedSource: Locale.Language(identifier: ayar.kaynak),
    target: Locale.Language(identifier: ayar.hedef))
var ceviriOnbellek: [String: String] = [:]

@MainActor
func cevir(_ metin: String) async -> String {
    if let hazir = ceviriOnbellek[metin] { return hazir }
    do {
        let sonuc = try await cevirmen.translate(metin).targetText
        ceviriOnbellek[metin] = sonuc
        return sonuc
    } catch {
        print("Çeviri hatası: \(error.localizedDescription)")
        return metin
    }
}

// MARK: - Sunucu

func gonder(_ yol: String, _ govde: [String: Any]) async {
    guard let url = URL(string: ayar.sunucu + yol) else { return }
    var istek = URLRequest(url: url)
    istek.httpMethod = "POST"
    istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
    istek.httpBody = try? JSONSerialization.data(withJSONObject: govde)
    do { _ = try await URLSession.shared.data(for: istek) } catch { print("Sunucuya ulaşılamadı: \(error.localizedDescription)") }
}

// MARK: - Pencere yakalama

func pencereBul() async throws -> SCWindow? {
    let icerik = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
    // Uygulama adı sistem diline göre değişebildiği için paket kimliğine de bakılır
    // (ör. Preview Türkçede "Önizleme"; Remote Play: com.playstation.RemotePlay).
    let aranan = ayar.uygulama.replacingOccurrences(of: " ", with: "")
    return icerik.windows
        .filter { w in
            let ad = w.owningApplication?.applicationName ?? ""
            let kimlik = w.owningApplication?.bundleIdentifier ?? ""
            let eslesti = ad.localizedCaseInsensitiveContains(ayar.uygulama) || kimlik.localizedCaseInsensitiveContains(aranan)
            return eslesti && w.frame.width > 300 && w.frame.height > 200
        }
        .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
}

func yakala(_ pencere: SCWindow) async throws -> CGImage {
    let filtre = SCContentFilter(desktopIndependentWindow: pencere)
    let yapilandirma = SCStreamConfiguration()
    let olcek = CGFloat(filtre.pointPixelScale)
    yapilandirma.width = Int(pencere.frame.width * olcek)
    yapilandirma.height = Int(pencere.frame.height * olcek)
    yapilandirma.showsCursor = false
    return try await SCScreenshotManager.captureImage(contentFilter: filtre, configuration: yapilandirma)
}

// MARK: - Çalıştır

if let dosya = ayar.dosya {
    guard let img = dosyadanYukle(dosya) else { print("Görüntü açılamadı: \(dosya)"); exit(1) }
    let bolge = kirp(img)
    if let o = ayar.onizleme { kaydet(bolge, o) }
    // İlk tur model yüklemesini de içerir; sonraki turlar gerçek hızı gösterir.
    for tur in 1...3 {
        var t = Date()
        let metin = try metniOku(bolge)
        print("[\(tur)] Okunan (\(Int(Date().timeIntervalSince(t) * 1000)) ms): \(metin)")
        ceviriOnbellek.removeAll()
        t = Date()
        let ceviri = await cevir(metin)
        print("[\(tur)] Çeviri (\(Int(Date().timeIntervalSince(t) * 1000)) ms): \(ceviri)")
    }
    exit(0)
}

print("Çeviri modeli hazırlanıyor…")
_ = await cevir("Hello.")
print("\"\(ayar.uygulama)\" penceresi izleniyor (\(ayar.fps) kare/sn). Durdurmak için Ctrl+C.")

var pencere: SCWindow?
var pencereAranma = Date.distantPast
var pencereBekleniyor = false
var aday = "", adayMetin = "", adayTekrar = 0
var gonderilen = ""
var bosKare = 0
let bekleme = UInt64(1_000_000_000 / ayar.fps)

while true {
    let basla = Date()
    do {
        if pencere == nil || Date().timeIntervalSince(pencereAranma) > 5 {
            pencereAranma = Date()
            let yeni = try await pencereBul()
            if yeni == nil && pencere != nil { print("Pencere kayboldu, bekleniyor…") }
            if yeni != nil && pencere == nil {
                print("Pencere bulundu: \(yeni!.title ?? ayar.uygulama)")
                pencereBekleniyor = false
            }
            pencere = yeni
        }
        guard let p = pencere else {
            if !pencereBekleniyor { print("\"\(ayar.uygulama)\" penceresi bulunamadı; açılması bekleniyor…") }
            pencereBekleniyor = true
            try await Task.sleep(nanoseconds: 1_000_000_000)
            continue
        }

        let bolge = kirp(try await yakala(p))
        if let o = ayar.onizleme { kaydet(bolge, o) }
        let metin = try metniOku(bolge)
        let s = sade(metin)

        if s.count < 3 {
            // Altyazı ekrandan kalktıysa TV'deki çeviriyi de kaldır.
            bosKare += 1
            if bosKare == 2 && !gonderilen.isEmpty {
                await gonder("/clear", [:])
                gonderilen = ""
            }
            aday = ""
        } else {
            bosKare = 0
            if benzer(s, aday) { adayTekrar += 1 } else { aday = s; adayTekrar = 1 }
            adayMetin = metin
            // İki kare üst üste aynı okunduysa kararlı say; daktilo efektinde metin tamamlanınca gider.
            if adayTekrar == 2 && !benzer(s, gonderilen) {
                let t = Date()
                let ceviri = await cevir(adayMetin)
                gonderilen = s
                // Çeviri kaynağıyla aynıysa metin zaten hedef dildedir (ör. PS5'in Türkçe menüleri).
                if benzer(sade(ceviri), s, esik: 0.9) {
                    print("Atlandı (zaten çevrili): \(adayMetin)")
                    continue
                }
                print("EN: \(adayMetin)\nTR: \(ceviri)  (\(Int(Date().timeIntervalSince(t) * 1000)) ms)")
                await gonder("/say", ["text": ceviri, "original": adayMetin, "duration": 15000])
            }
        }
    } catch {
        print("Hata: \(error.localizedDescription)")
        pencere = nil
        if !gonderilen.isEmpty {
            await gonder("/clear", [:])
            gonderilen = ""
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    let gecen = UInt64(Date().timeIntervalSince(basla) * 1_000_000_000)
    if gecen < bekleme { try? await Task.sleep(nanoseconds: bekleme - gecen) }
}
