// SPDX-License-Identifier: AGPL-3.0-only
// design/logo.svg'den uygulama simgelerini üretir (macOS uygulaması ve TV uygulaması).
// Kullanım: swift scripts/make-icons.swift   (depo kökünden)

import AppKit

func render(_ svg: NSImage, size: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    svg.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

guard let logo = NSImage(contentsOfFile: "design/logo.svg") else { fatalError("design/logo.svg okunamadı") }

// macOS: 16–512 pt, 1x ve 2x.
let iconSet = "mac/CouchSubs/Resources/Assets.xcassets/AppIcon.appiconset"
try! FileManager.default.createDirectory(atPath: iconSet, withIntermediateDirectories: true)
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        render(logo, size: points * scale, to: "\(iconSet)/\(name)")
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "\(iconSet)/Contents.json"))

// Uygulama içindeki logo (vektör olarak kalır).
let logoSet = "mac/CouchSubs/Resources/Assets.xcassets/Logo.imageset/logo.svg"
try? FileManager.default.removeItem(atPath: logoSet)
try! FileManager.default.copyItem(atPath: "design/logo.svg", toPath: logoSet)

// TV (webOS): 80 ve 130 piksel.
render(logo, size: 80, to: "tv-webos/icon.png")
render(logo, size: 130, to: "tv-webos/largeIcon.png")
// Belgeler ve mağaza görselleri için büyük kopya.
render(logo, size: 1024, to: "design/logo-1024.png")
print("Simgeler üretildi.")
