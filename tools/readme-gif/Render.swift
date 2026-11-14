// Renders the frames of docs/brightmeup.gif. tools/readme-gif/build.sh compiles this file with
// the app views and turns the frames into the GIF.
import AppKit
import SwiftUI

let CANVAS = CGSize(width: 960, height: 540)
let FPS = 20.0
let DURATION = 13.0
let SHOT = CGSize(width: 800, height: 440)
let ORANGE = Color(red: 1, green: 0.62, blue: 0.12)

struct Assets {
   let stock: NSImage
   let light: NSImage
   let soft: NSImage
   let gray: NSImage
   let icon: NSImage
}

func clamp01(_ x: Double) -> Double {
   return min(max(x, 0), 1)
}

// Smooth step between two times: 0 before a, 1 after b.
func ease(_ t: Double, _ a: Double, _ b: Double) -> Double {
   let x = clamp01((t - a) / (b - a))

   return x * x * (3 - 2 * x)
}

func mix(_ a: Double, _ b: Double, _ p: Double) -> Double {
   return a + (b - a) * p
}

struct FrameView: View {
   let t: Double
   let assets: Assets

   // The page goes from dark to light with the wipe, and back to dark for the outro, so the loop joins.
   var backgroundLevel: Double {
      return mix(mix(0.07, 0.95, ease(t, 2.2, 4.4)), 0.07, ease(t, 11.0, 11.4))
   }

   var ink: Color {
      return backgroundLevel < 0.5 ? .white : Color(white: 0.1)
   }

   var body: some View {
      ZStack {
         Color(white: backgroundLevel)
         RadialGradient(colors: [ ORANGE.opacity(0.28), .clear ], center: .top, startRadius: 10, endRadius: 520)
         if t < 2.0 {
            intro.opacity(1 - ease(t, 1.5, 1.9))
         }
         if t >= 1.5 && t < 8.6 {
            screenshots.opacity(ease(t, 1.5, 1.9) * (1 - ease(t, 8.1, 8.5)))
         }
         if t >= 8.1 && t < 11.35 {
            areas.opacity(ease(t, 8.1, 8.5) * (1 - ease(t, 10.95, 11.3)))
         }
         if t >= 11.3 {
            outro.opacity(ease(t, 11.35, 11.75))
         }
      }
      .frame(width: CANVAS.width, height: CANVAS.height)
   }

   // MARK: Intro

   var intro: some View {
      let pop = ease(t, 0.1, 0.8)

      return VStack(spacing: 18) {
         Image(nsImage: assets.icon)
            .resizable()
            .frame(width: 150, height: 150)
            .scaleEffect(0.6 + 0.4 * pop)
            .rotationEffect(.degrees(-30 * (1 - pop)))
            .shadow(color: ORANGE.opacity(0.5), radius: 30)
         Text("BrightMeUp")
            .font(.system(size: 58, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .opacity(ease(t, 0.4, 0.9))
            .offset(y: 12 * (1 - ease(t, 0.4, 0.9)))
         Text("A bright look for Logic Pro")
            .font(.system(size: 24, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .opacity(ease(t, 0.7, 1.2))
      }
   }

   // MARK: Real screenshots: the wipe, then the presets

   var wipe: Double {
      return ease(t, 2.2, 4.4)
   }

   var headline: String {
      if t < 4.8 {
         return "Turn Logic Pro bright"
      }
      return "Pick a preset, or dial in your own"
   }

   var presetName: String {
      if t < 5.9 {
         return "Light"
      }
      return t < 7.1 ? "Soft" : "Gray"
   }

   var presetLightness: Double {
      return mix(mix(1, 0.85, ease(t, 5.7, 6.1)), 0.68, ease(t, 6.9, 7.3))
   }

   var screenshots: some View {
      return VStack(spacing: 20) {
         Text(headline)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(ink)
         ZStack(alignment: .topLeading) {
            shot(assets.stock)
            shot(assets.light)
               .mask(alignment: .leading) {
                  Rectangle().frame(width: SHOT.width * wipe)
               }
            shot(assets.soft).opacity(ease(t, 5.7, 6.1) * (1 - ease(t, 6.9, 7.3)))
            shot(assets.gray).opacity(ease(t, 6.9, 7.3))
            if wipe > 0 && wipe < 1 {
               wipeHandle.offset(x: SHOT.width * wipe - 22)
            }
            chip(t < 4.6 ? "Before" : presetName, filled: t >= 4.6)
               .padding(14)
               .frame(width: SHOT.width, alignment: t < 4.6 ? .trailing : .leading)
               .opacity(t < 4.6 ? 1 - wipe * 0.9 : 1)
            if t > 2.6 && t < 4.6 {
               chip("After", filled: true).padding(14).opacity(ease(t, 2.6, 3.0))
            }
         }
         .frame(width: SHOT.width, height: SHOT.height)
         .clipShape(RoundedRectangle(cornerRadius: 14))
         .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
         .overlay(alignment: .bottom) {
            if t >= 4.8 {
               slider.offset(y: 30).opacity(ease(t, 4.8, 5.2))
            }
         }
      }
      .offset(y: -6)
   }

   func shot(_ image: NSImage) -> some View {
      return Image(nsImage: image)
         .resizable()
         .interpolation(.high)
         .frame(width: SHOT.width, height: SHOT.height)
   }

   var wipeHandle: some View {
      return ZStack {
         Rectangle().fill(.white).frame(width: 3, height: SHOT.height)
         Circle().fill(.white).frame(width: 44, height: 44).shadow(color: .black.opacity(0.3), radius: 8)
         Image(systemName: "sun.max.fill").font(.system(size: 24)).foregroundStyle(ORANGE)
      }
      .frame(width: 44, height: SHOT.height)
   }

   func chip(_ text: String, filled: Bool) -> some View {
      return Text(text)
         .font(.system(size: 17, weight: .bold, design: .rounded))
         .foregroundStyle(filled ? .white : Color(white: 0.1))
         .padding(.horizontal, 14)
         .padding(.vertical, 6)
         .background(filled ? AnyShapeStyle(ORANGE) : AnyShapeStyle(.white.opacity(0.92)), in: Capsule())
   }

   var slider: some View {
      return HStack(spacing: 12) {
         Image(systemName: "sun.min.fill").foregroundStyle(Color(white: 0.45))
         ZStack(alignment: .leading) {
            Capsule().fill(Color(white: 0.85)).frame(width: 260, height: 6)
            Capsule().fill(ORANGE).frame(width: 260 * (presetLightness - 0.5) / 0.5, height: 6)
            Circle().fill(.white).frame(width: 20, height: 20).shadow(color: .black.opacity(0.25), radius: 3)
               .offset(x: 260 * (presetLightness - 0.5) / 0.5 - 10)
         }
         Image(systemName: "sun.max.fill").foregroundStyle(ORANGE)
         Text("\(Int((presetLightness * 100).rounded()))%")
            .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(Color(white: 0.15))
            .frame(width: 52, alignment: .trailing)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(.white, in: Capsule())
      .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
   }

   // MARK: Areas: the app's own previews with the values moving

   var areaIndex: Int {
      return t < 9.3 ? 0 : (t < 10.4 ? 1 : 2)
   }

   var areaNames: [String] {
      return [ "Mixer", "Piano Roll", "Plug-ins" ]
   }

   var liveTheme: ThemeValues {
      let s = 0.8 + 0.18 * sin((t - 8.1) * 2.4)

      return ThemeValues(surfaceMax: s, gamma: mix(1.0, 0.75, (s - 0.62) / 0.36))
   }

   var areas: some View {
      // 0 shows the mixer, 1 the Piano Roll, 2 the plug-in; fractions are the slides between them.
      let position = ease(t, 9.15, 9.45) + ease(t, 10.25, 10.55)
      let step = SHOT.width + 60

      return VStack(spacing: 20) {
         Text("Every part of Logic Pro, your way")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(ink)
         ZStack {
            MockMixer(theme: liveTheme).frame(width: SHOT.width, height: 340)
               .offset(x: (0 - position) * step)
            MockPianoRoll(theme: liveTheme).frame(width: SHOT.width, height: 340)
               .offset(x: (1 - position) * step)
            MockPlugin(theme: liveTheme).frame(width: SHOT.width, height: 340)
               .offset(x: (2 - position) * step)
         }
         .frame(width: CANVAS.width, height: 340)
         .clipped()
         .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
         HStack(spacing: 10) {
            chip(areaNames[areaIndex], filled: true)
            Text("Lightness \(Int((liveTheme.surfaceMax * 100).rounded()))%")
               .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
               .foregroundStyle(Color(white: 0.3))
         }
      }
   }

   // MARK: Outro

   var outro: some View {
      return VStack(spacing: 16) {
         Image(nsImage: assets.icon)
            .resizable()
            .frame(width: 110, height: 110)
            .shadow(color: ORANGE.opacity(0.5), radius: 26)
         Text("BrightMeUp")
            .font(.system(size: 52, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
         Text("30 presets  ·  8 areas  ·  back to stock in one click")
            .font(.system(size: 21, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
         HStack(spacing: 6) {
            Text("Powered by").foregroundStyle(.white.opacity(0.6))
            Text("InPlug.app").fontWeight(.bold).foregroundStyle(ORANGE)
         }
         .font(.system(size: 18, design: .rounded))
         .padding(.top, 8)
      }
   }
}

func load(_ path: String) -> NSImage {
   guard let image = NSImage(contentsOfFile: path) else {
      fatalError("Missing image \(path)")
   }
   return image
}

func writePNG(_ image: CGImage, to path: String) {
   let url = URL(fileURLWithPath: path) as CFURL

   guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
      fatalError("Cannot write \(path)")
   }
   CGImageDestinationAddImage(dest, image, nil)
   CGImageDestinationFinalize(dest)
}

@main
struct GifRender {
   @MainActor
   static func main() {
      let args = CommandLine.arguments
      let docs = args[1], icon = args[2], out = args[3]
      let assets = Assets(stock: load("\(docs)/compare-stock.png"), light: load("\(docs)/compare-light.png"),
         soft: load("\(docs)/compare-soft.png"), gray: load("\(docs)/compare-gray.png"), icon: load(icon))
      let frames = Int(DURATION * FPS)

      for i in 0..<frames {
         let renderer = ImageRenderer(content: FrameView(t: Double(i) / FPS, assets: assets))

         renderer.scale = 2
         guard let image = renderer.cgImage else {
            fatalError("Frame \(i) did not render")
         }
         writePNG(image, to: String(format: "%@/frame-%04d.png", out, i))
      }
      print("Rendered \(frames) frames")
   }
}
