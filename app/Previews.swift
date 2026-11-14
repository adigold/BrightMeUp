// Small drawings of other parts of Logic Pro, painted with the gray rule like MockStrip. The stock
// grays here are close estimates from stock Logic Pro, so the drawings show the direction of a
// change, not exact pixels.
import SwiftUI

let PREVIEW_HEIGHT = 300.0

struct PreviewKind: Identifiable {
   let key: String
   let name: String
   // The areas whose values paint this preview, for the caption.
   let areas: [String]
   var id: String { return key }
}

let PREVIEW_KINDS = [
   PreviewKind(key: "main", name: "Main window", areas: [ "controlbar", "inspector", "tracks" ]),
   PreviewKind(key: "tracks", name: "Tracks", areas: [ "tracks" ]),
   PreviewKind(key: "mixer", name: "Mixer", areas: [ "mixer" ]),
   PreviewKind(key: "pianoroll", name: "Piano Roll", areas: [ "editors" ]),
   PreviewKind(key: "plugin", name: "Plug-ins", areas: []),
]

// The preview that shows each area best, so editing an area can bring its preview forward.
let PREVIEW_FOR_AREA = [ "tracks": "tracks", "mixer": "mixer", "editors": "pianoroll", "controlbar": "main",
   "inspector": "main", "browsers": "main", "windows": "main" ]

extension ThemeValues {
   // Translucent black recesses (meters, fader tracks) become a light shade, like the theme's well rule.
   func well(_ stock: Double) -> Color {
      return isStock ? Color(white: stock) : Color.black.opacity(0.12)
   }
}

func panel(_ theme: ThemeValues, _ stock: Double) -> Color {
   return theme.gray(stock)
}

// MARK: - Mixer

struct MockMixer: View {
   let theme: ThemeValues
   let names = [ "Doing Science", "Chill Vocal", "Nylon Guitar", "Grand Piano", "Mellotron", "Bass", "Drums",
      "Bus 1", "Bus 2", "Stereo Out" ]
   let colors = MOCK_TRACKS.map { (t) in return t.color } + [ Color(red: 0.62, green: 0.48, blue: 0.86),
      Color(red: 0.9, green: 0.5, blue: 0.4), Color(white: 0.55), Color(white: 0.55), Color(white: 0.55) ]
   let levels = [ 0.72, 0.6, 0.45, 0.55, 0.66, 0.62, 0.7, 0.5, 0.42, 0.78 ]
   let plugins = [ [ "Channel EQ", "Compressor" ], [ "Pitch Correct", "ChromaVerb" ], [ "Channel EQ" ],
      [ "Compressor", "Space D" ], [ "Tape Delay" ], [ "Amp Designer" ], [ "Drum Kit" ], [ "ChromaVerb" ],
      [ "Tape Delay" ], [ "Limiter" ] ]

   var body: some View {
      HStack(spacing: 1) {
         ForEach(0..<names.count, id: \.self) { (i) in
            strip(i)
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(theme.gray(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
   }

   func slot(_ text: String) -> some View {
      return Text(text)
         .font(.system(size: 9))
         .foregroundStyle(theme.gray(0.85))
         .lineLimit(1)
         .frame(maxWidth: .infinity, minHeight: 14)
         .background(theme.gray(0.27), in: RoundedRectangle(cornerRadius: 2))
   }

   func strip(_ i: Int) -> some View {
      let list = plugins[i]

      return VStack(spacing: 3) {
         slot("Setting")
         eqThumb
         slot(i < 7 ? "Input 1" : "Bus \(i - 6)")
         ForEach(0..<2, id: \.self) { (n) in
            slot(n < list.count ? list[n] : "")
         }
         slot(i < 7 ? "Bus 1" : "")
         slot("Stereo Out")
         knob
         fader(levels[i])
         HStack(spacing: 2) {
            button("M")
            button("S")
         }
         Text(names[i])
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.black)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 15)
            .background(colors[i])
      }
      .padding(4)
      .frame(maxWidth: 120, maxHeight: .infinity)
      .background(theme.gray(0.2))
   }

   var eqThumb: some View {
      return ZStack {
         theme.well(0.06)
         Path { (p) in
            p.move(to: CGPoint(x: 0, y: 14))
            p.addCurve(to: CGPoint(x: 70, y: 10), control1: CGPoint(x: 25, y: 4), control2: CGPoint(x: 45, y: 20))
         }
         .stroke(Color(red: 0.3, green: 0.75, blue: 0.95), lineWidth: 1.2)
      }
      .frame(height: 22)
      .clipShape(RoundedRectangle(cornerRadius: 2))
   }

   var knob: some View {
      return ZStack {
         Circle().fill(theme.gray(0.27))
         Circle().strokeBorder(theme.well(0.06), lineWidth: 2)
         Rectangle().fill(theme.gray(0.9)).frame(width: 1.5, height: 7).offset(y: -4)
      }
      .frame(width: 22, height: 22)
   }

   func fader(_ level: Double) -> some View {
      return GeometryReader { (geo) in
         HStack(alignment: .bottom, spacing: 6) {
            meter(level, height: geo.size.height)
            ZStack(alignment: .bottom) {
               Capsule().fill(theme.well(0.05)).frame(width: 5)
               RoundedRectangle(cornerRadius: 2)
                  .fill(theme.gray(0.55))
                  .frame(width: 22, height: 12)
                  .offset(y: -geo.size.height * level + 6)
            }
            .frame(width: 22)
         }
         .frame(maxWidth: .infinity)
      }
      .frame(minHeight: 50)
   }

   func meter(_ level: Double, height: Double) -> some View {
      return HStack(spacing: 1) {
         ForEach(0..<2, id: \.self) { (side) in
            ZStack(alignment: .bottom) {
               theme.well(0.04)
               LinearGradient(colors: [ .green, .green, .yellow ], startPoint: .bottom, endPoint: .top)
                  .frame(height: height * (level - Double(side) * 0.04))
            }
            .frame(width: 4)
         }
      }
   }

   func button(_ letter: String) -> some View {
      return Text(letter)
         .font(.system(size: 9, weight: .bold))
         .foregroundStyle(theme.gray(STOCK_LETTER))
         .frame(maxWidth: .infinity, minHeight: 14)
         .background(theme.gray(STOCK_BUTTON), in: RoundedRectangle(cornerRadius: 3))
   }
}

// MARK: - Piano Roll

struct MockPianoRoll: View {
   let theme: ThemeValues
   let rows = 24
   let black: Set<Int> = [ 1, 3, 6, 8, 10 ]
   // Notes as (row from the top, start in beats, length in beats).
   let notes: [ (Int, Double, Double) ] = [ (5, 0, 2), (9, 2, 1), (12, 3, 1), (5, 4, 1.5), (7, 6, 2), (12, 8, 3),
      (16, 8, 3), (9, 11.5, 1), (14, 12, 2), (5, 14, 2), (19, 16, 4), (12, 16, 4), (7, 20, 1), (9, 21, 1),
      (11, 22, 2), (16, 24, 3) ]
   let beatWidth = 34.0

   var body: some View {
      VStack(spacing: 0) {
         HStack(spacing: 0) {
            theme.gray(STOCK_ROW).frame(width: 60)
            ruler
         }
         .frame(height: RULER_HEIGHT)
         GeometryReader { (geo) in
            let rowHeight = geo.size.height / Double(rows)

            HStack(spacing: 0) {
               keyboard(rowHeight)
               grid(rowHeight)
            }
         }
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
   }

   var ruler: some View {
      return HStack(spacing: 0) {
         ForEach(0..<12, id: \.self) { (bar) in
            Text("\(bar + 1)")
               .font(.system(size: 9).monospacedDigit())
               .foregroundStyle(theme.gray(STOCK_LETTER))
               .padding(.leading, 3)
               .frame(width: beatWidth * 4, alignment: .leading)
         }
      }
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .background(theme.gray(STOCK_RULER))
      .clipped()
   }

   func isBlack(_ row: Int) -> Bool {
      return black.contains((rows - 1 - row) % 12)
   }

   func keyboard(_ rowHeight: Double) -> some View {
      return VStack(spacing: 0) {
         ForEach(0..<rows, id: \.self) { (row) in
            ZStack(alignment: .leading) {
               Color(white: 0.96)
               if isBlack(row) {
                  Color(white: 0.12).frame(width: 36)
               }
               if (rows - 1 - row) % 12 == 0 {
                  Text("C\(3 + (rows - 1 - row) / 12)").font(.system(size: 7)).foregroundStyle(.black)
                     .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 3)
               }
            }
            .frame(height: rowHeight)
            .overlay(alignment: .bottom) { Color(white: 0.7).frame(height: 0.5) }
         }
      }
      .frame(width: 60)
   }

   func grid(_ rowHeight: Double) -> some View {
      return ZStack(alignment: .topLeading) {
         VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { (row) in
               theme.gray(isBlack(row) ? 0.13 : 0.17).frame(height: rowHeight)
            }
         }
         HStack(spacing: 0) {
            ForEach(0..<48, id: \.self) { (beat) in
               theme.gray(beat % 4 == 0 ? 0.3 : 0.21).frame(width: 1)
               Spacer().frame(width: beatWidth - 1)
            }
         }
         ForEach(0..<notes.count, id: \.self) { (i) in
            let note = notes[i]

            RoundedRectangle(cornerRadius: 2)
               .fill(MOCK_TRACKS[1].color)
               .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
               .frame(width: note.2 * beatWidth - 1, height: rowHeight - 1)
               .offset(x: note.1 * beatWidth + 1, y: Double(note.0) * rowHeight)
         }
      }
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .clipped()
   }
}

// MARK: - Plug-in

struct MockPlugin: View {
   let theme: ThemeValues
   let knobs = [ ("Threshold", 0.35, "-18 dB"), ("Ratio", 0.5, "4:1"), ("Attack", 0.25, "15 ms"),
      ("Release", 0.6, "120 ms"), ("Knee", 0.4, "0.5"), ("Make Up", 0.55, "6 dB") ]

   var body: some View {
      VStack(spacing: 0) {
         header
         HStack(spacing: 18) {
            gainMeter
            VStack(spacing: 16) {
               HStack(spacing: 22) {
                  ForEach(0..<3, id: \.self) { (i) in knob(i) }
               }
               HStack(spacing: 22) {
                  ForEach(3..<6, id: \.self) { (i) in knob(i) }
               }
            }
            curveDisplay
            VStack(alignment: .leading, spacing: 8) {
               Text("COMPRESSOR").font(.system(size: 13, weight: .heavy)).foregroundStyle(theme.gray(0.92))
               ForEach([ "Platinum Digital", "Studio VCA", "Vintage Opto" ], id: \.self) { (model) in
                  Text(model)
                     .font(.system(size: 10))
                     .foregroundStyle(model == "Studio VCA" ? .black : theme.gray(0.8))
                     .padding(.horizontal, 8).padding(.vertical, 3)
                     .background(model == "Studio VCA" ? Color.orange : theme.gray(0.27),
                        in: RoundedRectangle(cornerRadius: 3))
               }
            }
         }
         .padding(18)
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .background(theme.gray(0.16))
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
   }

   var header: some View {
      return HStack(spacing: 8) {
         Image(systemName: "power").foregroundStyle(theme.gray(0.85))
         Text("Manual").font(.system(size: 11)).foregroundStyle(theme.gray(0.9))
            .padding(.horizontal, 10).padding(.vertical, 2)
            .background(theme.gray(0.3), in: RoundedRectangle(cornerRadius: 3))
         ForEach([ "Compare", "Copy", "Paste" ], id: \.self) { (label) in
            Text(label).font(.system(size: 10)).foregroundStyle(theme.gray(0.8))
         }
         Spacer()
         Text("View: 100%").font(.system(size: 10)).foregroundStyle(theme.gray(0.8))
      }
      .padding(.horizontal, 10)
      .frame(height: 26)
      .background(theme.gray(0.24))
   }

   // The transfer curve: straight below the threshold, flatter above it.
   var curveDisplay: some View {
      return GeometryReader { (geo) in
         let w = geo.size.width, h = geo.size.height

         ZStack {
            theme.well(0.07)
            Path { (p) in
               for i in 1..<4 {
                  p.move(to: CGPoint(x: w * Double(i) / 4, y: 0))
                  p.addLine(to: CGPoint(x: w * Double(i) / 4, y: h))
                  p.move(to: CGPoint(x: 0, y: h * Double(i) / 4))
                  p.addLine(to: CGPoint(x: w, y: h * Double(i) / 4))
               }
            }
            .stroke(theme.gray(0.25), lineWidth: 0.5)
            Path { (p) in
               p.move(to: CGPoint(x: 0, y: h))
               p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.45))
               p.addQuadCurve(to: CGPoint(x: w, y: h * 0.25), control: CGPoint(x: w * 0.65, y: h * 0.35))
            }
            .stroke(Color.orange, lineWidth: 2)
            Text("Gain Reduction").font(.system(size: 9)).foregroundStyle(theme.gray(0.7))
               .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(6)
         }
      }
      .frame(minWidth: 160, maxWidth: .infinity)
      .clipShape(RoundedRectangle(cornerRadius: 4))
   }

   var gainMeter: some View {
      return VStack(spacing: 4) {
         ZStack(alignment: .top) {
            theme.well(0.05)
            Color.orange.frame(height: 46)
         }
         .frame(width: 10)
         Text("GR").font(.system(size: 9)).foregroundStyle(theme.gray(0.7))
      }
   }

   func knob(_ i: Int) -> some View {
      let (label, value, shown) = knobs[i]

      return VStack(spacing: 5) {
         ZStack {
            Circle().stroke(theme.well(0.06), lineWidth: 4)
            Circle().trim(from: 0, to: value * 0.8)
               .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
               .rotationEffect(.degrees(126))
            Circle().fill(theme.gray(0.3)).padding(7)
            Rectangle().fill(theme.gray(0.95)).frame(width: 2, height: 9).offset(y: -9)
               .rotationEffect(.degrees(-144 + value * 288))
         }
         .frame(width: 44, height: 44)
         Text(label).font(.system(size: 10)).foregroundStyle(theme.gray(0.8))
         Text(shown).font(.system(size: 10).monospacedDigit()).foregroundStyle(theme.gray(0.95))
      }
   }
}

// MARK: - Main window: control bar, inspector and tracks

struct MockMainWindow: View {
   let controlBar: ThemeValues
   let inspector: ThemeValues
   let tracks: ThemeValues

   var body: some View {
      VStack(spacing: 0) {
         bar
         HStack(spacing: 0) {
            inspectorPanel
            MockStrip(theme: tracks, isFramed: false)
         }
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
   }

   func icon(_ name: String, tint: Color? = nil) -> some View {
      return Image(systemName: name)
         .font(.system(size: 12))
         .foregroundStyle(tint ?? controlBar.gray(0.88))
         .frame(width: 26, height: 22)
         .background(controlBar.gray(0.3), in: RoundedRectangle(cornerRadius: 4))
   }

   var bar: some View {
      return HStack(spacing: 6) {
         icon("music.note.list")
         icon("info.circle")
         icon("slider.horizontal.3")
         icon("scissors")
         Spacer(minLength: 8)
         icon("backward.fill")
         icon("forward.fill")
         icon("stop.fill")
         icon("play.fill")
         icon("record.circle", tint: .red)
         lcd
         icon("repeat", tint: Color(red: 0.95, green: 0.78, blue: 0.2))
         icon("tuningfork")
         icon("metronome")
         Spacer(minLength: 8)
         Capsule().fill(controlBar.well(0.08)).frame(width: 70, height: 4)
            .overlay(alignment: .leading) {
               Circle().fill(controlBar.gray(0.6)).frame(width: 10).offset(x: 46)
            }
      }
      .padding(.horizontal, 10)
      .frame(height: 44)
      .background(controlBar.gray(0.22))
   }

   var lcd: some View {
      return HStack(spacing: 14) {
         lcdField("5  3  1  1", "BAR  BEAT")
         lcdField("120", "TEMPO")
         lcdField("4/4", "TIME")
         lcdField("Cmaj", "KEY")
      }
      .padding(.horizontal, 12)
      .frame(height: 32)
      .background(controlBar.gray(0.1), in: RoundedRectangle(cornerRadius: 5))
   }

   func lcdField(_ value: String, _ label: String) -> some View {
      return VStack(spacing: 0) {
         Text(value).font(.system(size: 13, weight: .medium).monospacedDigit()).foregroundStyle(controlBar.gray(0.95))
         Text(label).font(.system(size: 7)).foregroundStyle(controlBar.gray(0.6))
      }
   }

   var inspectorPanel: some View {
      return VStack(alignment: .leading, spacing: 5) {
         Text("Region: Doing Science").font(.system(size: 10, weight: .semibold)).foregroundStyle(inspector.gray(0.95))
         ForEach([ ("Mute", "☐"), ("Loop", "☐"), ("Quantize", "Off"), ("Transpose", "0"), ("Fine Tune", "0"),
            ("Gain", "0 dB") ], id: \.0) { (row) in
            HStack {
               Text(row.0).foregroundStyle(inspector.gray(0.7))
               Spacer()
               Text(row.1).foregroundStyle(inspector.gray(0.95))
            }
            .font(.system(size: 9))
         }
         Divider().overlay(inspector.gray(0.3))
         Text("Track: Doing Science").font(.system(size: 10, weight: .semibold)).foregroundStyle(inspector.gray(0.95))
         RoundedRectangle(cornerRadius: 3).fill(inspector.gray(0.27)).frame(height: 16)
            .overlay(Text("Channel EQ").font(.system(size: 9)).foregroundStyle(inspector.gray(0.85)))
         Spacer(minLength: 0)
      }
      .padding(8)
      .frame(width: 150)
      .frame(maxHeight: .infinity)
      .background(inspector.gray(0.19))
   }
}
