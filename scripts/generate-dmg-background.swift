#!/usr/bin/env swift

import AppKit
import Foundation

private enum Canvas {
    static let size = NSSize(width: 720, height: 500)
    // Finder stores a DMG background as a static image rather than an
    // appearance-aware asset. A neutral palette stays readable alongside both
    // Aqua and Dark Aqua Finder chrome.
    static let textColor = NSColor(calibratedWhite: 0.98, alpha: 1)
    static let secondaryTextColor = NSColor(calibratedWhite: 0.82, alpha: 1)
    static let accentColor = NSColor(calibratedRed: 0.48, green: 0.70, blue: 1, alpha: 1)
}

private func rect(x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(x: x, y: Canvas.size.height - top - height, width: width, height: height)
}

private func drawText(
    _ value: String,
    in targetRect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping

    value.draw(
        in: targetRect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

private func drawStep(number: String, title: String, detail: String, top: CGFloat) {
    let badgeRect = rect(x: 74, top: top, width: 24, height: 24)
    let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 12, yRadius: 12)
    Canvas.accentColor.withAlphaComponent(0.15).setFill()
    badge.fill()

    drawText(
        number,
        in: rect(x: 74, top: top + 3, width: 24, height: 18),
        font: .systemFont(ofSize: 12, weight: .semibold),
        color: Canvas.accentColor,
        alignment: .center
    )
    drawText(
        title,
        in: rect(x: 112, top: top - 1, width: 520, height: 20),
        font: .systemFont(ofSize: 13, weight: .medium),
        color: Canvas.textColor
    )
    drawText(
        detail,
        in: rect(x: 112, top: top + 19, width: 520, height: 18),
        font: .systemFont(ofSize: 11.5, weight: .regular),
        color: Canvas.secondaryTextColor
    )
}

private func drawInstallLabelBand() {
    let areaRect = rect(x: 56, top: 218, width: 608, height: 42)
    let area = NSBezierPath(roundedRect: areaRect, xRadius: 12, yRadius: 12)
    NSColor(calibratedWhite: 0.40, alpha: 0.96).setFill()
    area.fill()

    NSColor.white.withAlphaComponent(0.14).setStroke()
    area.lineWidth = 1
    area.stroke()
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-dmg-background.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: Canvas.size)
image.lockFocus()

let fullRect = NSRect(origin: .zero, size: Canvas.size)
let gradient = NSGradient(
    starting: NSColor(calibratedWhite: 0.26, alpha: 1),
    ending: NSColor(calibratedWhite: 0.34, alpha: 1)
)
gradient?.draw(in: fullRect, angle: -90)

drawText(
    "DichThat",
    in: rect(x: 0, top: 28, width: Canvas.size.width, height: 34),
    font: .systemFont(ofSize: 25, weight: .semibold),
    color: Canvas.textColor,
    alignment: .center
)
drawText(
    "English ↔ Vietnamese, anywhere on macOS",
    in: rect(x: 0, top: 64, width: Canvas.size.width, height: 20),
    font: .systemFont(ofSize: 12.5, weight: .regular),
    color: Canvas.secondaryTextColor,
    alignment: .center
)

drawInstallLabelBand()

let arrowLine = NSBezierPath()
arrowLine.move(to: NSPoint(x: 310, y: Canvas.size.height - 170))
arrowLine.line(to: NSPoint(x: 410, y: Canvas.size.height - 170))
arrowLine.lineWidth = 2
Canvas.secondaryTextColor.withAlphaComponent(0.55).setStroke()
arrowLine.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 410, y: Canvas.size.height - 170))
arrowHead.line(to: NSPoint(x: 400, y: Canvas.size.height - 163))
arrowHead.move(to: NSPoint(x: 410, y: Canvas.size.height - 170))
arrowHead.line(to: NSPoint(x: 400, y: Canvas.size.height - 177))
arrowHead.lineWidth = 2
arrowHead.stroke()

let divider = NSBezierPath()
divider.move(to: NSPoint(x: 56, y: Canvas.size.height - 278))
divider.line(to: NSPoint(x: 664, y: Canvas.size.height - 278))
divider.lineWidth = 1
NSColor(calibratedWhite: 0.56, alpha: 0.65).setStroke()
divider.stroke()

drawStep(
    number: "1",
    title: "Kéo DichThat vào Applications",
    detail: "Chờ quá trình sao chép hoàn tất rồi mở app từ thư mục Applications.",
    top: 304
)
drawStep(
    number: "2",
    title: "Cho phép macOS mở app",
    detail: "Nếu bị chặn: System Settings → Privacy & Security → Open Anyway.",
    top: 364
)
drawStep(
    number: "3",
    title: "Cấp quyền Quick Translate",
    detail: "Trong DichThat, chọn Grant Access và bật DichThat trong Accessibility.",
    top: 424
)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Unable to render DMG background\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
