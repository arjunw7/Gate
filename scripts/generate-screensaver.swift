#!/usr/bin/env swift
// Generates a full-screen "Boop" banner image (JPEG) for demo video screensaver
// Winking smiley face + "boop" text centered on dark gradient background

import AppKit
import CoreText

// --- Config ---
let width: CGFloat = 3840   // 4K width
let height: CGFloat = 2160  // 4K height
let boopGreen = NSColor(red: 0.059, green: 0.729, blue: 0.514, alpha: 1.0)

// Register the custom font
let fontPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/Boop/Resources/Comfortaa-Medium.ttf")

if FileManager.default.fileExists(atPath: fontPath.path) {
    CTFontManagerRegisterFontsForURL(fontPath as CFURL, .process, nil)
    print("Loaded Comfortaa-Medium font")
} else {
    print("Warning: Comfortaa-Medium.ttf not found at \(fontPath.path)")
}

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// --- Background gradient ---
let bgColors = [
    NSColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1.0).cgColor,
    NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).cgColor,
]
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: bgColors as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: height),
    end: CGPoint(x: width, y: 0),
    options: []
)

// --- Layout: smiley face + "boop" text, centered ---
// Scale factor relative to icon script (based on ~100pt face at 1024px icon)
let faceScale: CGFloat = 2.5
let centerX = width / 2
let centerY = height / 2

// We'll draw the smiley to the left of "boop" text
// First measure the text to know total width
let fontSize: CGFloat = 120 * faceScale
let font = CTFontCreateWithName("Comfortaa-Medium" as CFString, fontSize, nil)
let attrString = NSAttributedString(string: "boop", attributes: [
    .font: font,
    .foregroundColor: boopGreen,
])
let line = CTLineCreateWithAttributedString(attrString)
let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

// Face dimensions
let eyeRadius: CGFloat = 26 * faceScale
let eyeGap: CGFloat = 66 * faceScale
let faceWidth = eyeGap + eyeRadius * 2
let spacing: CGFloat = 36 * faceScale  // gap between face and text

let totalWidth = faceWidth + spacing + textBounds.width
let startX = centerX - totalWidth / 2
let faceCenterX = startX + faceWidth / 2

// --- Draw smiley face ---
// CoreGraphics Y=0 at bottom
let eyeY = centerY + 22 * faceScale

// Left eye — filled circle
let leftEyeX = faceCenterX - eyeGap / 2
ctx.setFillColor(boopGreen.cgColor)
ctx.addEllipse(in: CGRect(
    x: leftEyeX - eyeRadius,
    y: eyeY - eyeRadius,
    width: eyeRadius * 2,
    height: eyeRadius * 2
))
ctx.fillPath()

// Right eye — winking chevron <
let rightEyeX = faceCenterX + eyeGap / 2
let chevronArm: CGFloat = 26 * faceScale
let chevronDepth: CGFloat = 20 * faceScale
let chevronPath = CGMutablePath()
chevronPath.move(to: CGPoint(x: rightEyeX + chevronDepth, y: eyeY + chevronArm))
chevronPath.addLine(to: CGPoint(x: rightEyeX - chevronDepth, y: eyeY))
chevronPath.addLine(to: CGPoint(x: rightEyeX + chevronDepth, y: eyeY - chevronArm))

ctx.setStrokeColor(boopGreen.cgColor)
ctx.setLineWidth(10 * faceScale)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(chevronPath)
ctx.strokePath()

// Mouth — curved smile
let mouthY = centerY - 32 * faceScale
let mouthWidth: CGFloat = 82 * faceScale
let mouthCurve: CGFloat = 36 * faceScale

let mouthPath = CGMutablePath()
mouthPath.move(to: CGPoint(x: faceCenterX - mouthWidth / 2, y: mouthY))
mouthPath.addQuadCurve(
    to: CGPoint(x: faceCenterX + mouthWidth / 2, y: mouthY),
    control: CGPoint(x: faceCenterX, y: mouthY - mouthCurve)
)

ctx.setStrokeColor(boopGreen.cgColor)
ctx.setLineWidth(10 * faceScale)
ctx.setLineCap(.round)
ctx.addPath(mouthPath)
ctx.strokePath()

// --- Draw "boop" text ---
let textX = startX + faceWidth + spacing
let textY = centerY - textBounds.height / 2 - textBounds.origin.y
ctx.textPosition = CGPoint(x: textX, y: textY)
CTLineDraw(line, ctx)

image.unlockFocus()

// --- Export as JPEG ---
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
else {
    print("Failed to generate JPEG")
    exit(1)
}

let outputPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("boop-screensaver.jpg")

try! jpegData.write(to: outputPath)
print("Screensaver image saved to \(outputPath.path)")
print("Resolution: \(Int(width))×\(Int(height))")
