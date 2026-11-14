// Draws the background of the installer window: a night-to-sunrise sky, "Drag it in. Brighten up.",
// and an arrow from the app to Applications. tools/dmg/build.sh renders it at 1x and 2x.
// The window is 660 by 420 points; the icons sit at (137, 245) and (523, 245), see settings.py.
import AppKit
import SwiftUI

let SIZE = CGSize(width: 660, height: 420)
let SUN = Color(red: 1, green: 0.66, blue: 0.16)

struct Background: View {
   var body: some View {
      ZStack(alignment: .topLeading) {
         // The sky brightens from the left (Logic Pro dark) to the right (BrightMeUp light).
         LinearGradient(stops: [
            .init(color: Color(red: 0.07, green: 0.06, blue: 0.13), location: 0),
            .init(color: Color(red: 0.22, green: 0.13, blue: 0.26), location: 0.42),
            .init(color: Color(red: 0.72, green: 0.33, blue: 0.24), location: 0.78),
            .init(color: Color(red: 0.98, green: 0.62, blue: 0.3), location: 1),
         ], startPoint: .leading, endPoint: .trailing)
         // A low sun glows behind Applications.
         RadialGradient(colors: [ Color(red: 1, green: 0.85, blue: 0.5).opacity(0.85), SUN.opacity(0.35), .clear ],
            center: UnitPoint(x: 523 / SIZE.width, y: 250 / SIZE.height), startRadius: 4, endRadius: 230)
         // A few stars on the dark side.
         ForEach(0..<14, id: \.self) { (i) in
            let x = Double((i * 73) % 240) + 18
            let y = Double((i * 151) % 160) + 150

            Circle().fill(.white.opacity(0.18 + Double(i % 4) * 0.12))
               .frame(width: i % 5 == 0 ? 3 : 2, height: i % 5 == 0 ? 3 : 2)
               .offset(x: x, y: y)
         }
         VStack(alignment: .leading, spacing: 2) {
            Text("Drag it in.")
               .font(.system(size: 46, weight: .black, design: .rounded))
               .foregroundStyle(.white)
            Text("Brighten up.")
               .font(.system(size: 46, weight: .black, design: .rounded))
               .foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.12))
               .padding(.horizontal, 8)
               .background(SUN, in: RoundedRectangle(cornerRadius: 6))
               .padding(.leading, -8)
         }
         .offset(x: 34, y: 22)
         arrow
         Text("Then open BrightMeUp from Applications")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
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
      .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
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
