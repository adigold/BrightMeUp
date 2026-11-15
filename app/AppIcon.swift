// Draws the app icon as a 1024 by 1024 PNG file. app/build.sh turns it into AppIcon.icns.
// The icon is a light switch turned on: a warm toggle on a white tile, for "turn Logic Pro light"
// (Adi, 2026-11-15).
import AppKit

let CANVAS = 1024.0
// The macOS icon grid: an 824 point rounded square in the center of the canvas.
let BODY = 824.0
let RADIUS = 185.0
// The toggle track and its knob, as parts of the tile.
let TRACK_WIDTH = BODY * 0.625
let TRACK_HEIGHT = BODY * 0.3125
let KNOB_INSET = BODY * 0.026

/**
 * Draws the switch: a warm track with the white knob on the right, the "on" side.
 *
 * @param center NSPoint - the center of the tile
 */
func drawSwitch(center: NSPoint) {
   let track = NSRect(x: center.x - TRACK_WIDTH / 2, y: center.y - TRACK_HEIGHT / 2, width: TRACK_WIDTH, height: TRACK_HEIGHT)
   let trackPath = NSBezierPath(roundedRect: track, xRadius: TRACK_HEIGHT / 2, yRadius: TRACK_HEIGHT / 2)
   let knobRadius = TRACK_HEIGHT / 2 - KNOB_INSET
   let knobCenter = NSPoint(x: track.maxX - TRACK_HEIGHT / 2, y: center.y)
   let knob = NSBezierPath(ovalIn: NSRect(x: knobCenter.x - knobRadius, y: knobCenter.y - knobRadius, width: 2 * knobRadius, height: 2 * knobRadius))
   let glow = NSShadow(), knobShadow = NSShadow()

   NSGraphicsContext.saveGraphicsState()
   glow.shadowColor = NSColor(srgbRed: 1, green: 0.6, blue: 0.1, alpha: 0.35)
   glow.shadowBlurRadius = 36
   glow.shadowOffset = NSSize(width: 0, height: -8)
   glow.set()
   NSColor(srgbRed: 1, green: 0.72, blue: 0.2, alpha: 1).setFill()
   trackPath.fill()
   NSGraphicsContext.restoreGraphicsState()
   NSGradient(starting: NSColor(srgbRed: 1, green: 0.82, blue: 0.36, alpha: 1),
      ending: NSColor(srgbRed: 1, green: 0.58, blue: 0.16, alpha: 1))!.draw(in: trackPath, angle: -90)

   NSGraphicsContext.saveGraphicsState()
   knobShadow.shadowColor = NSColor(white: 0, alpha: 0.28)
   knobShadow.shadowBlurRadius = 18
   knobShadow.shadowOffset = NSSize(width: 0, height: -6)
   knobShadow.set()
   NSColor.white.setFill()
   knob.fill()
   NSGraphicsContext.restoreGraphicsState()
   NSGradient(starting: NSColor.white, ending: NSColor(white: 0.93, alpha: 1))!.draw(in: knob, angle: -90)
   // The knob is a small record, for music and Logic Pro.
   NSColor(white: 0.55, alpha: 0.28).setStroke()
   for step in stride(from: 0.92, to: 0.36, by: -0.09) {
      let r = knobRadius * step
      let ring = NSBezierPath(ovalIn: NSRect(x: knobCenter.x - r, y: knobCenter.y - r, width: 2 * r, height: 2 * r))

      ring.lineWidth = 2.5
      ring.stroke()
   }
   let label = knobRadius * 0.3
   NSGradient(starting: NSColor(srgbRed: 1, green: 0.82, blue: 0.36, alpha: 1),
      ending: NSColor(srgbRed: 1, green: 0.58, blue: 0.16, alpha: 1))!
      .draw(in: NSBezierPath(ovalIn: NSRect(x: knobCenter.x - label, y: knobCenter.y - label, width: 2 * label, height: 2 * label)), angle: -90)
   let hole = knobRadius * 0.06
   NSColor(white: 0.25, alpha: 1).setFill()
   NSBezierPath(ovalIn: NSRect(x: knobCenter.x - hole, y: knobCenter.y - hole, width: 2 * hole, height: 2 * hole)).fill()
}

/**
 * Draws the whole icon into a bitmap.
 *
 * @return NSBitmapImageRep - the 1024 by 1024 icon
 */
func drawIcon() -> NSBitmapImageRep {
   let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(CANVAS), pixelsHigh: Int(CANVAS), bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
   let body = NSRect(x: (CANVAS - BODY) / 2, y: (CANVAS - BODY) / 2, width: BODY, height: BODY)
   let shape = NSBezierPath(roundedRect: body, xRadius: RADIUS, yRadius: RADIUS)
   let shadow = NSShadow()

   NSGraphicsContext.saveGraphicsState()
   NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
   NSGraphicsContext.saveGraphicsState()
   shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
   shadow.shadowBlurRadius = 20
   shadow.shadowOffset = NSSize(width: 0, height: -10)
   shadow.set()
   NSColor.white.setFill()
   shape.fill()
   NSGraphicsContext.restoreGraphicsState()
   NSGradient(starting: NSColor.white, ending: NSColor(white: 0.91, alpha: 1))!.draw(in: shape, angle: -90)
   drawSwitch(center: NSPoint(x: body.midX, y: body.midY))
   NSGraphicsContext.restoreGraphicsState()
   return rep
}

let png = drawIcon().representation(using: .png, properties: [:])!

try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
