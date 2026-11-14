// Launcher for the light theme. It stores the brightness settings in its own preferences
// domain, which theme/light-theme.m reads at launch, and starts Logic Pro with the theme.
import AppKit
import SwiftUI

let LOGIC_ID = "com.apple.logic10"
let LOGIC_PATH = "/Applications/Logic Pro.app"
// The limits, the gray rule and SELECTED_ROW_WHITE come from theme/gray-rule.h.
let SURFACE_RANGE = SURFACE_MAX_MIN...1.0
let GAMMA_RANGE = GAMMA_MIN...GAMMA_MAX
let PRESET_MATCH = 0.005
let CUSTOM = "Custom"
let WINDOW_SIZE = CGSize(width: 940, height: 680)
let SIDEBAR_WIDTH = 230.0
let HEADER_WIDTH = 290.0
let ROW_HEIGHT = 34.0
let RULER_HEIGHT = 20.0
let BAR_WIDTH = 46.0
let BAR_COUNT = 12
let STRIP_FOOTER = 14.0

// Stock Logic Pro grays of the track area, measured in a render of Logic Pro without the theme.
let STOCK_ROW = 0.18
let STOCK_SEPARATOR = 0.25
let STOCK_BUTTON = 0.26
let STOCK_SLIDER = 0.11
let STOCK_KNOB = 0.51
let STOCK_LANE = 0.1
let STOCK_GRID = 0.15
let STOCK_RULER = 0.25
let STOCK_LETTER = 0.9
let STOCK_TEXT = 1.0

struct AreaValue: Codable, Equatable {
   var mode: Int
   var surfaceMax: Double
   var gamma: Double
}

struct AreaInfo: Identifiable {
   let key: String
   let name: String
   let summary: String
   let symbol: String
   var id: String { return key }
}

// The keys match AREA_KEYS in theme/light-theme.m.
let AREAS = [
   AreaInfo(key: "tracks", name: "Tracks area", summary: "Track headers, regions, ruler, automation, Live Loops",
      symbol: "rectangle.split.3x1"),
   AreaInfo(key: "mixer", name: "Mixer", summary: "Channel strips, faders, meters, sends", symbol: "slider.vertical.3"),
   AreaInfo(key: "editors", name: "Editors", summary: "Piano Roll, Score, Step Sequencer, Event List, Flex Pitch",
      symbol: "pianokeys"),
   AreaInfo(key: "controlbar", name: "Control bar", summary: "Transport, display, tempo and counters", symbol: "playpause"),
   AreaInfo(key: "inspector", name: "Inspector and Smart Controls", summary: "Region and track inspector, Smart Controls",
      symbol: "info.circle"),
   AreaInfo(key: "browsers", name: "Browsers and library", summary: "Library, Loop and File browsers, new track sheet",
      symbol: "folder"),
   AreaInfo(key: "plugins", name: "Plug-in windows", summary: "Stock instruments and effects", symbol: "waveform"),
   AreaInfo(key: "windows", name: "Windows and panels", summary: "Shared backgrounds, dividers, buttons, text",
      symbol: "macwindow"),
]

let OVERALL = AreaValue(mode: Int(AREA_MODE_OVERALL), surfaceMax: SURFACE_MAX_DEFAULT, gamma: GAMMA_DEFAULT)
let ORIGINAL = AreaValue(mode: Int(AREA_MODE_ORIGINAL), surfaceMax: SURFACE_MAX_DEFAULT, gamma: GAMMA_DEFAULT)

func custom(_ s: Double, _ g: Double) -> AreaValue {
   return AreaValue(mode: Int(AREA_MODE_CUSTOM), surfaceMax: s, gamma: g)
}

struct Preset: Identifiable {
   let name: String
   let group: String
   let summary: String
   let surfaceMax: Double
   let gamma: Double
   var areas: [String: AreaValue] = [:]
   var id: String { return name }
}

let PRESET_GROUPS = [ "Bright", "Balanced", "Dim", "High contrast", "Low contrast", "By area" ]

let PRESETS = [
   Preset(name: "Light", group: "Bright", summary: "Default", surfaceMax: SURFACE_MAX_DEFAULT, gamma: GAMMA_DEFAULT),
   Preset(name: "Paper", group: "Bright", summary: "Bright, airy", surfaceMax: 0.97, gamma: 0.55),
   Preset(name: "Snow", group: "Bright", summary: "Whitest grays", surfaceMax: 1, gamma: 0.45),
   Preset(name: "Daylight", group: "Bright", summary: "Bright room", surfaceMax: 1, gamma: 0.62),
   Preset(name: "Morning", group: "Bright", summary: "Bright, a bit softer", surfaceMax: 0.94, gamma: 0.7),
   Preset(name: "Soft", group: "Balanced", summary: "Dimmer grays", surfaceMax: 0.85, gamma: 0.85),
   Preset(name: "Linen", group: "Balanced", summary: "Light, calm", surfaceMax: 0.9, gamma: 0.8),
   Preset(name: "Mist", group: "Balanced", summary: "Light, flat", surfaceMax: 0.88, gamma: 0.65),
   Preset(name: "Studio", group: "Balanced", summary: "Long sessions", surfaceMax: 0.76, gamma: 1.1),
   Preset(name: "Slate", group: "Balanced", summary: "Deeper grays", surfaceMax: 0.8, gamma: 1.2),
   Preset(name: "Gray", group: "Balanced", summary: "Middle gray", surfaceMax: 0.68, gamma: 1),
   Preset(name: "Dusk", group: "Dim", summary: "Dim", surfaceMax: 0.56, gamma: 1.35),
   Preset(name: "Evening", group: "Dim", summary: "Late sessions", surfaceMax: 0.62, gamma: 1.2),
   Preset(name: "Twilight", group: "Dim", summary: "Dimmer", surfaceMax: 0.53, gamma: 1.5),
   Preset(name: "Night Light", group: "Dim", summary: "Darkest", surfaceMax: 0.5, gamma: 1.8),
   Preset(name: "Contrast", group: "High contrast", summary: "Strong separation", surfaceMax: 1, gamma: 1.4),
   Preset(name: "Bold", group: "High contrast", summary: "Darker controls", surfaceMax: 0.92, gamma: 1.6),
   Preset(name: "Ink", group: "High contrast", summary: "Maximum contrast", surfaceMax: 0.96, gamma: 2),
   Preset(name: "Gentle", group: "Low contrast", summary: "Soft edges", surfaceMax: 0.92, gamma: 0.45),
   Preset(name: "Haze", group: "Low contrast", summary: "Flat, quiet", surfaceMax: 0.8, gamma: 0.4),
   Preset(name: "Fog", group: "Low contrast", summary: "Flat, dim", surfaceMax: 0.7, gamma: 0.35),
   Preset(name: "Dark Plug-ins", group: "By area", summary: "Light, plug-ins stay dark", surfaceMax: SURFACE_MAX_DEFAULT,
      gamma: GAMMA_DEFAULT, areas: [ "plugins": ORIGINAL ]),
   Preset(name: "Producer", group: "By area", summary: "Bright editors, dark plug-ins", surfaceMax: 0.9, gamma: 0.8,
      areas: [ "editors": custom(1, 0.6), "plugins": ORIGINAL ]),
   Preset(name: "Mix Engineer", group: "By area", summary: "Calm mixer, dark plug-ins", surfaceMax: 0.85, gamma: 0.85,
      areas: [ "mixer": custom(0.78, 1.05), "plugins": ORIGINAL ]),
   Preset(name: "Focus Tracks", group: "By area", summary: "Bright tracks, dim the rest", surfaceMax: 0.66, gamma: 1.1,
      areas: [ "tracks": custom(1, 0.75) ]),
   Preset(name: "Bright Editors", group: "By area", summary: "Soft, editors brighter", surfaceMax: 0.85, gamma: 0.85,
      areas: [ "editors": custom(1, 0.6) ]),
   Preset(name: "Dim Mixer", group: "By area", summary: "Light, mixer dimmer", surfaceMax: SURFACE_MAX_DEFAULT,
      gamma: GAMMA_DEFAULT, areas: [ "mixer": custom(0.7, 1.1) ]),
   Preset(name: "Calm Panels", group: "By area", summary: "Dim inspector and browsers", surfaceMax: SURFACE_MAX_DEFAULT,
      gamma: GAMMA_DEFAULT, areas: [ "inspector": custom(0.82, 1), "browsers": custom(0.82, 1) ]),
   Preset(name: "Bold Control Bar", group: "By area", summary: "Contrast in the control bar", surfaceMax: 0.9,
      gamma: 0.8, areas: [ "controlbar": custom(0.96, 1.6) ]),
   Preset(name: "Night Session", group: "By area", summary: "Dim, tracks lifted, dark plug-ins", surfaceMax: 0.56,
      gamma: 1.35, areas: [ "tracks": custom(0.7, 1.1), "plugins": ORIGINAL ]),
   Preset(name: "Score Writer", group: "By area", summary: "Paper-white editors", surfaceMax: 0.8, gamma: 1,
      areas: [ "editors": custom(1, 0.45) ]),
]
let USER_TAG = "user:"

struct SavedPreset: Codable, Identifiable {
   let name: String
   let surfaceMax: Double
   let gamma: Double
   // Missing in presets saved before areas existed.
   var areas: [String: AreaValue]?
   var id: String { return USER_TAG + name }
}

/**
 * Reads the presets that the user saved, stored as JSON in the preferences.
 *
 * @param json String - the stored JSON
 * @return [SavedPreset] - the presets, or none if the JSON is not valid
 */
func decodeSaved(_ json: String) -> [SavedPreset] {
   return (try? JSONDecoder().decode([SavedPreset].self, from: Data(json.utf8))) ?? []
}

/**
 * Keeps the setting of each area in the preferences, as area.<key>.mode, area.<key>.surfaceMax
 * and area.<key>.gamma. The theme reads the same keys.
 */
final class AreaStore: ObservableObject {
   @Published var values: [String: AreaValue] {
      didSet { save() }
   }

   init() {
      let defaults = UserDefaults.standard
      var loaded: [String: AreaValue] = [:]

      for area in AREAS {
         let prefix = "area.\(area.key)."

         loaded[area.key] = AreaValue(
            mode: defaults.object(forKey: prefix + "mode") as? Int ?? Int(AREA_MODE_OVERALL),
            surfaceMax: defaults.object(forKey: prefix + "surfaceMax") as? Double ?? SURFACE_MAX_DEFAULT,
            gamma: defaults.object(forKey: prefix + "gamma") as? Double ?? GAMMA_DEFAULT)
      }
      values = loaded
   }

   func save() {
      let defaults = UserDefaults.standard

      for (key, value) in values {
         defaults.set(value.mode, forKey: "area.\(key).mode")
         defaults.set(value.surfaceMax, forKey: "area.\(key).surfaceMax")
         defaults.set(value.gamma, forKey: "area.\(key).gamma")
      }
   }

   subscript(key: String) -> AreaValue {
      get { return values[key] ?? OVERALL }
      set { values[key] = newValue }
   }

   /**
    * Reports if the areas match a preset. Values only count for custom areas.
    *
    * @param areas [String: AreaValue] - the areas of the preset; a missing area follows the overall values
    * @return Bool - true if every area matches
    */
   func matches(_ areas: [String: AreaValue]) -> Bool {
      return AREAS.allSatisfy { (area) in
         let mine = self[area.key]
         let theirs = areas[area.key] ?? OVERALL

         if mine.mode != theirs.mode {
            return false
         }
         return mine.mode != Int(AREA_MODE_CUSTOM) || (abs(mine.surfaceMax - theirs.surfaceMax) < PRESET_MATCH
            && abs(mine.gamma - theirs.gamma) < PRESET_MATCH)
      }
   }

   func setAll(_ areas: [String: AreaValue]) {
      var next: [String: AreaValue] = [:]

      for area in AREAS {
         next[area.key] = areas[area.key] ?? OVERALL
      }
      values = next
   }

   var customized: [String: AreaValue] {
      return values.filter { (_, value) in return value.mode != Int(AREA_MODE_OVERALL) }
   }
}

struct MockTrack: Identifiable {
   let number: Int
   let name: String
   let color: Color
   let hasRecord: Bool
   let isSoloed: Bool
   let volume: Double
   // Regions as (first bar, length in bars).
   let regions: [ (Double, Double) ]
   var id: Int { return number }
}

let MOCK_TRACKS = [
   MockTrack(number: 1, name: "Doing Science", color: Color(red: 0.84, green: 0.78, blue: 0.2),
      hasRecord: true, isSoloed: false, volume: 0.72, regions: [ (1, 2), (3, 2), (6, 2) ]),
   MockTrack(number: 2, name: "Chill Vocal Sequences", color: Color(red: 0.6, green: 0.8, blue: 0.24),
      hasRecord: true, isSoloed: true, volume: 0.6, regions: [ (0, 3), (4, 3) ]),
   MockTrack(number: 3, name: "Plucked Nylon Guitar", color: Color(red: 0.25, green: 0.72, blue: 0.68),
      hasRecord: false, isSoloed: false, volume: 0.45, regions: [ (2, 4) ]),
   MockTrack(number: 4, name: "Steinway Grand Piano", color: Color(red: 0.3, green: 0.76, blue: 0.82),
      hasRecord: true, isSoloed: false, volume: 0.55, regions: [ (0, 2), (5, 3) ]),
   MockTrack(number: 5, name: "Mellotron", color: Color(red: 0.36, green: 0.56, blue: 0.9),
      hasRecord: false, isSoloed: false, volume: 0.66, regions: [ (3, 2), (7, 2) ]),
]

struct ThemeValues {
   let surfaceMax: Double
   let gamma: Double
   // True paints the stock dark grays, for the Before view of the preview.
   var isStock = false

   func gray(_ stock: Double) -> Color {
      return Color(white: isStock ? stock : mapGrayLevel(stock, surfaceMax, gamma))
   }
}

enum LaunchStatus {
   case ready, logicRunning, logicMissing, libraryMissing, failed(String)
   case logicUntested(tested: String, installed: String)

   var text: String {
      switch self {
      case .ready: return "Ready. Logic Pro starts with the theme."
      case .logicRunning: return "Quit Logic Pro first. The theme loads only at launch."
      case .logicMissing: return "Logic Pro is not in the Applications folder."
      case .libraryMissing: return "The theme library is missing. Download the app again."
      case .logicUntested(let tested, let installed):
         return "Tested with Logic Pro build \(tested), but you have build \(installed). Some parts can stay dark."
      case .failed(let error): return "Logic Pro did not start. \(error)"
      }
   }

   var symbol: String {
      switch self {
      case .ready: return "checkmark.circle.fill"
      case .failed: return "xmark.octagon.fill"
      default: return "exclamationmark.triangle.fill"
      }
   }

   var tint: Color {
      switch self {
      case .ready: return .green
      case .failed: return .red
      default: return .orange
      }
   }

   var canStart: Bool {
      switch self {
      case .ready, .logicUntested, .failed: return true
      default: return false
      }
   }
}

/**
 * Reports if a copy of Logic Pro is running.
 *
 * @return Bool - true if Logic Pro is running
 */
func isLogicRunning() -> Bool {
   return !NSRunningApplication.runningApplications(withBundleIdentifier: LOGIC_ID).isEmpty
}

/**
 * Finds the state of the launch from the files and the running apps.
 *
 * @return LaunchStatus - the state to show
 */
func getLaunchStatus() -> LaunchStatus {
   let tested = Bundle.main.infoDictionary?["TestedLogicBuild"] as? String
   let installed = Bundle(path: LOGIC_PATH)?.infoDictionary?["CFBundleVersion"] as? String

   if Bundle.main.path(forResource: "light-theme", ofType: "dylib") == nil {
      return .libraryMissing
   }
   guard let installed else {
      return .logicMissing
   }
   if isLogicRunning() {
      return .logicRunning
   }
   if let tested, tested != installed {
      return .logicUntested(tested: tested, installed: installed)
   }
   return .ready
}

/**
 * A small drawing of Logic Pro track headers and regions, painted with the gray rule.
 */
struct MockStrip: View {
   let theme: ThemeValues

   var body: some View {
      VStack(spacing: 0) {
         HStack(spacing: 0) {
            theme.gray(STOCK_ROW).frame(width: HEADER_WIDTH)
            ruler
         }
         .frame(height: RULER_HEIGHT)
         ForEach(MOCK_TRACKS) { (track) in
            separator
            HStack(spacing: 0) {
               header(track)
               lane(track)
            }
            .frame(height: ROW_HEIGHT)
         }
         separator
         HStack(spacing: 0) {
            theme.gray(STOCK_ROW).frame(width: HEADER_WIDTH)
            laneGrid
         }
         .frame(height: STRIP_FOOTER)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
   }

   var separator: some View {
      return theme.gray(STOCK_SEPARATOR).frame(height: 1)
   }

   var ruler: some View {
      return HStack(spacing: 0) {
         ForEach(0..<BAR_COUNT, id: \.self) { (bar) in
            Text("\(bar * 4 + 1)")
               .font(.system(size: 9).monospacedDigit())
               .foregroundStyle(theme.gray(STOCK_LETTER))
               .padding(.leading, 3)
               .frame(width: BAR_WIDTH, alignment: .leading)
         }
      }
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .background(theme.gray(STOCK_RULER))
      .clipped()
   }

   var laneGrid: some View {
      return HStack(spacing: 0) {
         ForEach(0..<BAR_COUNT, id: \.self) { (_) in
            theme.gray(STOCK_GRID).frame(width: 1)
            Spacer().frame(width: BAR_WIDTH - 1)
         }
      }
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .background(theme.gray(STOCK_LANE))
      .clipped()
   }

   func header(_ track: MockTrack) -> some View {
      let isSelected = track.number == 1
      let rowColor = isSelected
         ? (theme.isStock ? Color(white: 0.3) : Color(white: SELECTED_ROW_WHITE * theme.surfaceMax))
         : theme.gray(STOCK_ROW)

      return HStack(spacing: 6) {
         Text("\(track.number)")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.black)
            .frame(width: 22, height: ROW_HEIGHT)
            .background(track.color)
         HStack(spacing: 2) {
            button("M", isOn: false, onColor: .clear)
            button("S", isOn: track.isSoloed, onColor: Color(red: 0.95, green: 0.78, blue: 0.2))
            if track.hasRecord {
               button("R", isOn: false, onColor: .clear)
               button("I", isOn: false, onColor: .clear)
            }
         }
         .frame(width: 76, alignment: .leading)
         Text(track.name)
            .font(.system(size: 11))
            .foregroundStyle(theme.gray(STOCK_TEXT))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
         volume(track.volume)
      }
      .padding(.trailing, 8)
      .frame(width: HEADER_WIDTH)
      .background(rowColor)
   }

   func button(_ letter: String, isOn: Bool, onColor: Color) -> some View {
      return Text(letter)
         .font(.system(size: 9, weight: .bold))
         .foregroundStyle(isOn ? .black : theme.gray(STOCK_LETTER))
         .frame(width: 17, height: 15)
         .background(isOn ? onColor : theme.gray(STOCK_BUTTON), in: RoundedRectangle(cornerRadius: 3))
   }

   func volume(_ level: Double) -> some View {
      return ZStack(alignment: .leading) {
         Capsule().fill(theme.gray(STOCK_SLIDER)).frame(width: 58, height: 12)
         Circle().fill(theme.gray(STOCK_KNOB)).frame(width: 10, height: 10).offset(x: 1 + level * 46)
      }
   }

   func lane(_ track: MockTrack) -> some View {
      return ZStack(alignment: .topLeading) {
         laneGrid
         ForEach(Array(track.regions.enumerated()), id: \.offset) { (_, region) in
            Text(track.name)
               .font(.system(size: 9, weight: .medium))
               .foregroundStyle(.white)
               .lineLimit(1)
               .padding(.horizontal, 3)
               .padding(.top, 2)
               .frame(width: region.1 * BAR_WIDTH - 2, height: ROW_HEIGHT - 4, alignment: .topLeading)
               .background(track.color, in: RoundedRectangle(cornerRadius: 3))
               .offset(x: region.0 * BAR_WIDTH + 1, y: 2)
         }
      }
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .clipped()
   }
}

struct ContentView: View {
   @AppStorage("surfaceMax") var surfaceMax = SURFACE_MAX_DEFAULT
   @AppStorage("gamma") var gamma = GAMMA_DEFAULT
   @AppStorage("savedPresets") var savedJSON = "[]"
   @AppStorage("tab") var tab = "overall"
   @StateObject var areas = AreaStore()
   @State var status = getLaunchStatus()
   @State var columns = NavigationSplitViewVisibility.all
   @State var showsStock = false
   @State var isNaming = false
   @State var newName = ""

   var saved: [SavedPreset] {
      return decodeSaved(savedJSON)
   }

   var isDefault: Bool {
      return abs(surfaceMax - SURFACE_MAX_DEFAULT) < PRESET_MATCH && abs(gamma - GAMMA_DEFAULT) < PRESET_MATCH
         && areas.customized.isEmpty
   }

   var presetName: String {
      let matches = { (s: Double, g: Double, a: [String: AreaValue]) in
         return abs(s - surfaceMax) < PRESET_MATCH && abs(g - gamma) < PRESET_MATCH && areas.matches(a)
      }

      if let p = PRESETS.first(where: { (p) in return matches(p.surfaceMax, p.gamma, p.areas) }) {
         return p.name
      }
      if let p = saved.first(where: { (p) in return matches(p.surfaceMax, p.gamma, p.areas ?? [:]) }) {
         return p.id
      }
      return CUSTOM
   }

   var selection: Binding<String?> {
      return Binding(
         get: { return presetName },
         set: { (name) in
            if let p = PRESETS.first(where: { (p) in return p.name == name }) {
               apply(p.surfaceMax, p.gamma, p.areas)
            } else if let p = saved.first(where: { (p) in return p.id == name }) {
               apply(p.surfaceMax, p.gamma, p.areas ?? [:])
            }
         }
      )
   }

   /**
    * The values that paint the preview: the tracks area values, or the stock grays.
    */
   var previewTheme: ThemeValues {
      let tracks = areas["tracks"]

      if showsStock || tracks.mode == Int(AREA_MODE_ORIGINAL) {
         return ThemeValues(surfaceMax: surfaceMax, gamma: gamma, isStock: true)
      }
      if tracks.mode == Int(AREA_MODE_CUSTOM) {
         return ThemeValues(surfaceMax: tracks.surfaceMax, gamma: tracks.gamma)
      }
      return ThemeValues(surfaceMax: surfaceMax, gamma: gamma)
   }

   func apply(_ s: Double, _ g: Double, _ a: [String: AreaValue]) {
      surfaceMax = clamp(s, SURFACE_RANGE)
      gamma = clamp(g, GAMMA_RANGE)
      areas.setAll(a)
   }

   func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
      return min(max(value, range.lowerBound), range.upperBound)
   }

   func resetToDefault() {
      apply(SURFACE_MAX_DEFAULT, GAMMA_DEFAULT, [:])
   }

   func store(_ list: [SavedPreset]) {
      if let data = try? JSONEncoder().encode(list), let json = String(data: data, encoding: .utf8) {
         savedJSON = json
      }
   }

   /**
    * Saves the current values and areas as a preset with the typed name. A preset with the same
    * name is replaced.
    */
   func savePreset() {
      let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
      var list = saved.filter { (p) in return p.name != name }

      isNaming = false
      newName = ""
      if name.isEmpty {
         return
      }
      list.append(SavedPreset(name: name, surfaceMax: surfaceMax, gamma: gamma, areas: areas.customized))
      store(list)
   }

   func deletePreset(_ preset: SavedPreset) {
      store(saved.filter { (p) in return p.id != preset.id })
   }

   var body: some View {
      let workspace = NSWorkspace.shared.notificationCenter

      NavigationSplitView(columnVisibility: $columns) {
         List(selection: selection) {
            ForEach(PRESET_GROUPS, id: \.self) { (group) in
               Section(group) {
                  ForEach(PRESETS.filter { (p) in return p.group == group }) { (p) in
                     presetRow(name: p.name, summary: p.summary, surface: p.surfaceMax, hasAreas: !p.areas.isEmpty)
                        .tag(p.name)
                  }
               }
            }
            Section("My presets") {
               ForEach(saved) { (p) in
                  presetRow(name: p.name, summary: "Saved", surface: p.surfaceMax, hasAreas: !(p.areas ?? [:]).isEmpty)
                     .tag(p.id)
                     .contextMenu {
                        Button("Delete \(p.name)", role: .destructive) { deletePreset(p) }
                     }
               }
               presetRow(name: CUSTOM, summary: "Your own values", surface: surfaceMax, hasAreas: false).tag(CUSTOM)
            }
         }
         .navigationSplitViewColumnWidth(SIDEBAR_WIDTH)
         .toolbar(removing: .sidebarToggle)
      } detail: {
         VStack(alignment: .leading, spacing: 14) {
            HStack {
               Text("Preview").font(.headline)
               Text(areas["tracks"].mode == Int(AREA_MODE_OVERALL) ? "" : "Tracks area values")
                  .font(.caption).foregroundStyle(.secondary)
               Spacer()
               Picker("Preview", selection: $showsStock) {
                  Text("Before").tag(true)
                  Text("After").tag(false)
               }
               .pickerStyle(.segmented)
               .labelsHidden()
               .frame(width: 150)
               .help("Before shows stock Logic Pro. After shows your theme.")
            }
            MockStrip(theme: previewTheme)
               .accessibilityElement(children: .ignore)
               .accessibilityLabel(showsStock ? "Preview of stock Logic Pro tracks"
                  : "Preview of Logic Pro tracks with your theme")
            HStack {
               Picker("Settings", selection: $tab) {
                  Text("Overall").tag("overall")
                  Text("Areas").tag("areas")
               }
               .pickerStyle(.segmented)
               .labelsHidden()
               .frame(width: 200)
               Spacer()
               Button {
                  resetToDefault()
               } label: {
                  Label("Reset to Default", systemImage: "arrow.counterclockwise")
               }
               .keyboardShortcut("0", modifiers: .command)
               .disabled(isDefault)
               .help("Back to the default Light values for everything (Command 0)")
               Button {
                  newName = presetName == CUSTOM ? "" : presetName
                  isNaming = true
               } label: {
                  Label("Save as Preset", systemImage: "plus")
               }
               .keyboardShortcut("s", modifiers: .command)
               .popover(isPresented: $isNaming, arrowEdge: .bottom) {
                  HStack {
                     TextField("Preset name", text: $newName).frame(width: 160).onSubmit(savePreset)
                     Button("Save", action: savePreset).keyboardShortcut(.defaultAction)
                  }
                  .padding(12)
               }
            }
            if tab == "areas" {
               areaList
            } else {
               Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                  sliderRow("Lightness", value: $surfaceMax, range: SURFACE_RANGE, low: "Dark", high: "Light",
                     shown: percent(surfaceMax), step: 0.01, defaultValue: SURFACE_MAX_DEFAULT)
                  sliderRow("Middle grays", value: $gamma, range: GAMMA_RANGE, low: "Light", high: "Dark",
                     shown: String(format: "%.2f", gamma), step: 0.05, defaultValue: GAMMA_DEFAULT)
               }
               Text("These values apply to every area that follows Overall. Use Areas to change one part of Logic Pro on its own.")
                  .font(.caption).foregroundStyle(.secondary)
               Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
               Image(systemName: status.symbol).foregroundStyle(status.tint)
               Text(status.text).foregroundStyle(.secondary).lineLimit(2)
               Spacer()
               Button("Start Logic Pro", action: startLogic)
                  .keyboardShortcut(.defaultAction)
                  .controlSize(.large)
                  .disabled(!status.canStart)
            }
            VStack(spacing: 3) {
               HStack(spacing: 5) {
                  Text("Powered by")
                  Link("InPlug.app", destination: URL(string: "https://inplug.app")!)
                     .fontWeight(.semibold)
                     .foregroundStyle(.tint)
                     .help("Open inplug.app")
               }
               .font(.body)
               Text("© \(String(Calendar.current.component(.year, from: Date()))) InPlug. All rights reserved.")
                  .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
         }
         .padding(20)
         .navigationTitle("BrightMeUp")
      }
      .frame(width: WINDOW_SIZE.width, height: WINDOW_SIZE.height)
      .onReceive(workspace.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { (_) in
         status = getLaunchStatus()
      }
      .onReceive(workspace.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { (_) in
         status = getLaunchStatus()
      }
   }

   var areaList: some View {
      return VStack(alignment: .leading, spacing: 6) {
         HStack {
            Text("Overall follows the Overall tab. Custom gives the area its own values. Original keeps the Logic Pro colors of that area.")
               .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("All to Overall") { areas.setAll([:]) }
               .controlSize(.small)
               .disabled(areas.customized.isEmpty)
         }
         ScrollView {
            VStack(spacing: 0) {
               ForEach(AREAS) { (area) in
                  areaRow(area)
                  Divider()
               }
            }
         }
         .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
      }
   }

   /**
    * One area: its name, a swatch of its surface and text, the mode and, for a custom area, its values.
    */
   func areaRow(_ area: AreaInfo) -> some View {
      let value = areas[area.key]
      let isCustom = value.mode == Int(AREA_MODE_CUSTOM)
      let theme = value.mode == Int(AREA_MODE_ORIGINAL) ? ThemeValues(surfaceMax: 1, gamma: 1, isStock: true)
         : isCustom ? ThemeValues(surfaceMax: value.surfaceMax, gamma: value.gamma)
         : ThemeValues(surfaceMax: surfaceMax, gamma: gamma)
      let mode = Binding<Int>(
         get: { return areas[area.key].mode },
         set: { (newMode) in
            var next = areas[area.key]

            // A new custom area starts from the overall values.
            if newMode == Int(AREA_MODE_CUSTOM) && next.mode != Int(AREA_MODE_CUSTOM) {
               next.surfaceMax = surfaceMax
               next.gamma = gamma
            }
            next.mode = newMode
            areas[area.key] = next
         }
      )
      let lightest = Binding<Double>(
         get: { return areas[area.key].surfaceMax },
         set: { (v) in areas[area.key].surfaceMax = v }
      )
      let curve = Binding<Double>(
         get: { return areas[area.key].gamma },
         set: { (v) in areas[area.key].gamma = v }
      )

      return VStack(alignment: .leading, spacing: 8) {
         HStack(spacing: 10) {
            Image(systemName: area.symbol).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
               Text(area.name)
               Text(area.summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text("Aa")
               .font(.system(size: 11, weight: .semibold))
               .foregroundStyle(theme.gray(STOCK_TEXT))
               .frame(width: 36, height: 22)
               .background(theme.gray(STOCK_ROW), in: RoundedRectangle(cornerRadius: 4))
               .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
            Picker(area.name, selection: mode) {
               Text("Overall").tag(Int(AREA_MODE_OVERALL))
               Text("Custom").tag(Int(AREA_MODE_CUSTOM))
               Text("Original").tag(Int(AREA_MODE_ORIGINAL))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)
         }
         if isCustom {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
               sliderRow("Lightness", value: lightest, range: SURFACE_RANGE, low: "Dark", high: "Light",
                  shown: percent(value.surfaceMax), step: 0.01, defaultValue: surfaceMax)
               sliderRow("Middle grays", value: curve, range: GAMMA_RANGE, low: "Light", high: "Dark",
                  shown: String(format: "%.2f", value.gamma), step: 0.05, defaultValue: gamma)
            }
            .controlSize(.small)
            .padding(.leading, 32)
         }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
   }

   func presetRow(name: String, summary: String, surface: Double, hasAreas: Bool) -> some View {
      return HStack(spacing: 10) {
         RoundedRectangle(cornerRadius: 4)
            .fill(Color(white: surface))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
            .frame(width: 18, height: 18)
         VStack(alignment: .leading, spacing: 1) {
            Text(name)
            Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
         }
         if hasAreas {
            Spacer()
            Image(systemName: "square.grid.2x2").font(.caption).foregroundStyle(.secondary)
               .help("This preset sets some areas on their own")
         }
      }
      .padding(.vertical, 2)
   }

   func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, low: String,
      high: String, shown: String, step: Double, defaultValue: Double) -> some View {
      let nudge = { (delta: Double) in
         value.wrappedValue = min(max(value.wrappedValue + delta, range.lowerBound), range.upperBound)
      }

      return GridRow {
         Text(label)
         Slider(value: value, in: range) {
            Text(label)
         } minimumValueLabel: {
            Text(low).font(.caption).foregroundStyle(.secondary)
         } maximumValueLabel: {
            Text(high).font(.caption).foregroundStyle(.secondary)
         }
         .labelsHidden()
         .accessibilityValue(shown)
         Text(shown).monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
         HStack(spacing: 2) {
            Button { nudge(-step) } label: { Image(systemName: "minus") }
               .help("Fine step down")
            Button { nudge(step) } label: { Image(systemName: "plus") }
               .help("Fine step up")
            Button { value.wrappedValue = defaultValue } label: { Image(systemName: "arrow.uturn.backward") }
               .help("Reset \(label)")
               .disabled(abs(value.wrappedValue - defaultValue) < PRESET_MATCH)
         }
         .buttonStyle(.borderless)
         .controlSize(.small)
      }
   }

   func percent(_ value: Double) -> String {
      return "\(Int((value * 100).rounded()))%"
   }

   /**
    * Starts Logic Pro with the theme library from this app bundle, then quits this app.
    */
   func startLogic() {
      let open = Process()

      guard let library = Bundle.main.path(forResource: "light-theme", ofType: "dylib") else {
         return
      }
      if isLogicRunning() {
         status = .logicRunning
         return
      }
      open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      open.arguments = [ "-n", "--env", "DYLD_INSERT_LIBRARIES=\(library)", "-a", LOGIC_PATH ]
      do {
         try open.run()
         open.waitUntilExit()
      } catch {
         status = .failed(error.localizedDescription)
         return
      }
      if open.terminationStatus != 0 {
         status = .failed("The open command ended with code \(open.terminationStatus).")
         return
      }
      NSApp.terminate(nil)
   }
}

class AppDelegate: NSObject, NSApplicationDelegate {
   /**
    * Removes the download quarantine flag from the theme library in this app bundle. The user
    * approved this app in Gatekeeper, and without this step macOS asks a second time when
    * Logic Pro loads the library.
    */
   func applicationDidFinishLaunching(_ notification: Notification) {
      if let library = Bundle.main.path(forResource: "light-theme", ofType: "dylib") {
         removexattr(library, "com.apple.quarantine", 0)
      }
   }

   func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
      return true
   }
}

@main
struct LauncherApp: App {
   @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

   var body: some Scene {
      Window("BrightMeUp", id: "main") {
         ContentView()
      }
      .windowResizability(.contentSize)
   }
}
