#!/usr/bin/env swift

import AppKit
import Foundation

private enum Canvas {
    static let size = NSSize(width: 720, height: 500)
    // Finder stores a DMG background as a static image. Match the compact dark
    // popover surface used by Quick Translate so installation feels cohesive.
    static let textColor = NSColor(calibratedWhite: 0.98, alpha: 1)
    static let secondaryTextColor = NSColor(calibratedWhite: 0.68, alpha: 1)
    static let accentColor = NSColor(calibratedRed: 0.48, green: 0.70, blue: 1, alpha: 1)
    static let backgroundColor = NSColor(calibratedWhite: 0.105, alpha: 1)
    static let labelBandColor = NSColor(calibratedWhite: 0.16, alpha: 0.96)
    static let dividerColor = NSColor(calibratedWhite: 0.28, alpha: 0.70)
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
    let areaRect = rect(x: 56, top: 168, width: 608, height: 42)
    let area = NSBezierPath(roundedRect: areaRect, xRadius: 12, yRadius: 12)
    Canvas.labelBandColor.setFill()
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
Canvas.backgroundColor.setFill()
fullRect.fill()

drawInstallLabelBand()

let arrowLine = NSBezierPath()
arrowLine.move(to: NSPoint(x: 310, y: Canvas.size.height - 120))
arrowLine.line(to: NSPoint(x: 410, y: Canvas.size.height - 120))
arrowLine.lineWidth = 2
Canvas.secondaryTextColor.withAlphaComponent(0.55).setStroke()
arrowLine.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 410, y: Canvas.size.height - 120))
arrowHead.line(to: NSPoint(x: 400, y: Canvas.size.height - 113))
arrowHead.move(to: NSPoint(x: 410, y: Canvas.size.height - 120))
arrowHead.line(to: NSPoint(x: 400, y: Canvas.size.height - 127))
arrowHead.lineWidth = 2
arrowHead.stroke()

let divider = NSBezierPath()
divider.move(to: NSPoint(x: 56, y: Canvas.size.height - 228))
divider.line(to: NSPoint(x: 664, y: Canvas.size.height - 228))
divider.lineWidth = 1
Canvas.dividerColor.setStroke()
divider.stroke()

drawStep(
    number: "1",
    title: "Kéo DichThat vào Applications",
    detail: "Chờ quá trình sao chép hoàn tất rồi mở app từ thư mục Applications.",
    top: 254
)
drawStep(
    number: "2",
    title: "Cho phép macOS mở app",
    detail: "Nếu bị chặn: System Settings → Privacy & Security → Open Anyway.",
    top: 314
)
drawStep(
    number: "3",
    title: "Cấp quyền Quick Translate",
    detail: "Trong DichThat, chọn Grant Access và bật DichThat trong Accessibility.",
    top: 374
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
