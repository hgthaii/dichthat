import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum IconDesign {
    static let canvasSize = 1024
    static let cornerRadius: CGFloat = 228
    static let glyphInset: CGFloat = 220
    static let topColor = NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.25, alpha: 1).cgColor
    static let bottomColor = NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.085, alpha: 1).cgColor
    static let glyphColor = NSColor.white.cgColor
    static let sizes: [(name: String, pixels: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: generate-app-icon.swift <repository-root>")
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sourceURL = root.appendingPathComponent("Resources/BrandDT.png")
let outputURL = root.appendingPathComponent("Resources/AppIcon.icns")
let iconsetURL = root.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
guard let sourceImage = NSImage(contentsOf: sourceURL),
      let source = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else { fatalError("Could not read BrandDT.png") }

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func render(size: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { fatalError("Could not create icon context") }

    let scale = CGFloat(size) / CGFloat(IconDesign.canvasSize)
    context.scaleBy(x: scale, y: scale)
    let canvas = CGRect(x: 0, y: 0, width: IconDesign.canvasSize, height: IconDesign.canvasSize)
    let background = CGPath(
        roundedRect: canvas.insetBy(dx: 48, dy: 48),
        cornerWidth: IconDesign.cornerRadius,
        cornerHeight: IconDesign.cornerRadius,
        transform: nil
    )
    context.saveGState()
    context.addPath(background)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [IconDesign.topColor, IconDesign.bottomColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: canvas.midX, y: canvas.maxY),
        end: CGPoint(x: canvas.midX, y: canvas.minY),
        options: []
    )
    context.restoreGState()

    let glyphRect = canvas.insetBy(dx: IconDesign.glyphInset, dy: IconDesign.glyphInset)
    context.saveGState()
    context.clip(to: glyphRect, mask: source)
    context.setFillColor(IconDesign.glyphColor)
    context.fill(glyphRect)
    context.restoreGState()
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { fatalError("Could not create PNG destination") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write PNG") }
}

for output in IconDesign.sizes {
    write(render(size: output.pixels), to: iconsetURL.appendingPathComponent(output.name))
}
write(render(size: IconDesign.canvasSize), to: root.appendingPathComponent("Resources/AppIconSource.png"))

let icnsEntries: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]
var entryData = Data()
for entry in icnsEntries {
    let payload = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.filename))
    entryData.append(contentsOf: entry.type.utf8)
    var entryLength = UInt32(payload.count + 8).bigEndian
    withUnsafeBytes(of: &entryLength) { entryData.append(contentsOf: $0) }
    entryData.append(payload)
}
var icns = Data("icns".utf8)
var totalLength = UInt32(entryData.count + 8).bigEndian
withUnsafeBytes(of: &totalLength) { icns.append(contentsOf: $0) }
icns.append(entryData)
try icns.write(to: outputURL, options: .atomic)
try? fileManager.removeItem(at: iconsetURL)
