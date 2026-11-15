// Draws the background of the installer window, in the style of the light switch icon: a warm
// white backdrop, "Drag it in. Switch it on." with the second line on an orange switch track, and
// an arrow from the app to Applications. tools/dmg/build.sh renders it at 1x and 2x.
// The layout is 660 by 420 points inside a 660 by 545 window; the icons sit at (137, 245) and (523, 245), see settings.py.
import AppKit
import SwiftUI

// Taller than the 420 point layout: when Finder shows its path and status bars they cover the
// bottom, and when it hides them the extra space fills the window.
let SIZE = CGSize(width: 660, height: 545)
let SUN = Color(red: 1, green: 0.66, blue: 0.16)
let SUN_LIGHT = Color(red: 1, green: 0.82, blue: 0.36)
let SUN_DEEP = Color(red: 1, green: 0.58, blue: 0.16)
let INK = Color(red: 0.12, green: 0.11, blue: 0.13)

struct Background: View {
   var body: some View {
      ZStack(alignment: .topLeading) {
         LinearGradient(colors: [ Color(red: 1, green: 0.99, blue: 0.97), Color(red: 0.95, green: 0.93, blue: 0.9) ],
            startPoint: .top, endPoint: .bottom)
         // A soft warm light behind Applications, where the app goes.
         RadialGradient(colors: [ SUN_LIGHT.opacity(0.45), SUN.opacity(0.12), .clear ],
            center: UnitPoint(x: 523 / SIZE.width, y: 250 / SIZE.height), startRadius: 4, endRadius: 200)
         VStack(alignment: .leading, spacing: 8) {
            Text("Drag it in.")
               .font(.system(size: 46, weight: .black, design: .rounded))
               .foregroundStyle(INK)
            // The second line sits on a switch track with its knob on the right, like the icon.
            HStack(spacing: 14) {
               Text("Switch it on.")
                  .font(.system(size: 40, weight: .black, design: .rounded))
                  .foregroundStyle(.white)
               Circle().fill(.white).frame(width: 46, height: 46)
                  .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
            }
            .padding(.leading, 26)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Capsule().fill(LinearGradient(colors: [ SUN_LIGHT, SUN_DEEP ], startPoint: .top, endPoint: .bottom)))
            .shadow(color: SUN.opacity(0.35), radius: 10, y: 4)
         }
         .offset(x: 34, y: 22)
         arrow
         Text("Then open BrightMeUp from Applications")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(INK.opacity(0.6))
            .frame(width: SIZE.width)
            .offset(y: 384)
      }
      .frame(width: SIZE.width, height: SIZE.height)
   }

   // A curved arrow over the gap between the two icons, from left to right.
   var arrow: some View {
      return ZStack {
         Path { (p) in
            p.move(to: CGPoint(x: 232, y: 262))
            p.addQuadCurve(to: CGPoint(x: 418, y: 238), control: CGPoint(x: 318, y: 160))
         }
         .stroke(SUN, style: StrokeStyle(lineWidth: 9, lineCap: .round))
         Path { (p) in
            p.move(to: CGPoint(x: 396, y: 210))
            p.addLine(to: CGPoint(x: 420, y: 240))
            p.addLine(to: CGPoint(x: 384, y: 250))
         }
         .stroke(SUN, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
      }
      .shadow(color: SUN.opacity(0.3), radius: 6, y: 3)
   }
}

@MainActor
func write(scale: Double, to path: String) {
   let renderer = ImageRenderer(content: Background())

   renderer.scale = scale
   guard let image = renderer.cgImage else {
      fatalError("The background did not render")
   }
   let rep = NSBitmapImageRep(cgImage: image)

   // 72 dpi at 1x and 144 dpi at 2x, so tiffutil pairs them as one Retina image.
   rep.size = NSSize(width: SIZE.width, height: SIZE.height)
   try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

@main
struct RenderBackground {
   @MainActor
   static func main() {
      let out = CommandLine.arguments[1]

      write(scale: 1, to: "\(out)/background.png")
      write(scale: 2, to: "\(out)/background@2x.png")
   }
}
