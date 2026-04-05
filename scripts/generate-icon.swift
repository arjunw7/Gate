#!/usr/bin/env swift
// Generates Boop app icon as .icns with the winking smiley face
// Two eyes (left dot, right winking chevron), curved smile below
// Dark gradient background filling the full canvas (no white border)

import AppKit

let boopGreen = NSColor(red: 0.059, green: 0.729, blue: 0.514, alpha: 1.0) // #0FBA84

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Background: fill ENTIRE canvas with dark gradient (no squircle clip — macOS applies its own mask)
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
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // Face layout — matched to in-app header proportions
    // CoreGraphics has Y=0 at bottom
    let centerX = size * 0.5
    let centerY = size * 0.5

    // Eye dimensions — scaled up to fill the icon
    let eyeRadius = size * 0.10
    let eyeGap = size * 0.26
    let eyeY = centerY + size * 0.08

    // Left eye — filled circle
    let leftEyeCenter = CGPoint(x: centerX - eyeGap / 2, y: eyeY)
    let leftEyePath = CGMutablePath()
    leftEyePath.addEllipse(in: CGRect(
        x: leftEyeCenter.x - eyeRadius,
        y: leftEyeCenter.y - eyeRadius,
        width: eyeRadius * 2,
        height: eyeRadius * 2
    ))
    ctx.setFillColor(boopGreen.cgColor)
    ctx.addPath(leftEyePath)
    ctx.fillPath()

    // Right eye — winking chevron < pointing left, sized to match the dot
    let rightEyeCenter = CGPoint(x: centerX + eyeGap / 2, y: eyeY)
    let chevronArm = size * 0.10
    let chevronDepth = size * 0.08
    let chevronPath = CGMutablePath()
    chevronPath.move(to: CGPoint(x: rightEyeCenter.x + chevronDepth, y: rightEyeCenter.y + chevronArm))
    chevronPath.addLine(to: CGPoint(x: rightEyeCenter.x - chevronDepth, y: rightEyeCenter.y))
    chevronPath.addLine(to: CGPoint(x: rightEyeCenter.x + chevronDepth, y: rightEyeCenter.y - chevronArm))

    ctx.setStrokeColor(boopGreen.cgColor)
    ctx.setLineWidth(size * 0.04)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(chevronPath)
    ctx.strokePath()

    // Mouth — scaled up
    let mouthY = centerY - size * 0.12
    let mouthWidth = size * 0.32
    let mouthCurve = size * 0.14

    let mouthPath = CGMutablePath()
    mouthPath.move(to: CGPoint(x: centerX - mouthWidth / 2, y: mouthY))
    mouthPath.addQuadCurve(
        to: CGPoint(x: centerX + mouthWidth / 2, y: mouthY),
        control: CGPoint(x: centerX, y: mouthY - mouthCurve)
    )

    ctx.setStrokeColor(boopGreen.cgColor)
    ctx.setLineWidth(size * 0.04)
    ctx.setLineCap(.round)
    ctx.addPath(mouthPath)
    ctx.strokePath()

    image.unlockFocus()
    return image
}

// Generate all required sizes for .icns
let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let iconsetPath = "/tmp/Boop.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = drawIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData)
    else {
        print("Failed to generate \(name)")
        continue
    }
    bitmap.size = NSSize(width: size, height: size)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        continue
    }
    let filePath = "\(iconsetPath)/\(name).png"
    try! pngData.write(to: URL(fileURLWithPath: filePath))
    print("Generated \(name).png (\(Int(size))×\(Int(size)))")
}

print("\nIconset ready at \(iconsetPath)")
print("Run: iconutil -c icns \(iconsetPath)")
