#!/usr/bin/env swift

import AppKit
import Foundation

private enum Canvas {
    static let size = NSSize(width: 720, height: 240)
    // Finder stores a DMG background as a static image. Match the compact dark
    // popover surface used by Quick Translate so installation feels cohesive.
    static let secondaryTextColor = NSColor(calibratedWhite: 0.68, alpha: 1)
    static let backgroundColor = NSColor(calibratedWhite: 0.105, alpha: 1)
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

let arrowLine = NSBezierPath()
arrowLine.move(to: NSPoint(x: 310, y: Canvas.size.height - 105))
arrowLine.line(to: NSPoint(x: 410, y: Canvas.size.height - 105))
arrowLine.lineWidth = 2
Canvas.secondaryTextColor.withAlphaComponent(0.55).setStroke()
arrowLine.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 410, y: Canvas.size.height - 105))
arrowHead.line(to: NSPoint(x: 400, y: Canvas.size.height - 98))
arrowHead.move(to: NSPoint(x: 410, y: Canvas.size.height - 105))
arrowHead.line(to: NSPoint(x: 400, y: Canvas.size.height - 112))
arrowHead.lineWidth = 2
arrowHead.stroke()

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
