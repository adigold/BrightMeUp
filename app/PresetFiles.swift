// Shares presets as files, so users can send each other a look (Adi, 2026-11-15). A preset file is
// small JSON that holds only the preset values; loading one never runs anything and only changes
// BrightMeUp's own settings.
import AppKit
import UniformTypeIdentifiers

let PRESET_FILE_FORMAT = 1
let PRESET_FILE_SUFFIX = " - BrightMeUp.json"
// A real preset file is a few hundred bytes; anything much bigger is not one.
let PRESET_FILE_MAX_BYTES = 64 * 1024

struct PresetFile: Codable {
   let brightMeUpPreset: Int
   let preset: SavedPreset
}

/**
 * Checks a preset read from a file and brings every value into the allowed range. Unknown areas
 * are dropped, and the plug-ins area always stays original.
 *
 * @param preset SavedPreset - the preset from the file
 * @return SavedPreset? - the safe preset, or nil if it has no usable name
 */
func sanitized(_ preset: SavedPreset) -> SavedPreset? {
   let name = String(preset.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
   let keep = { (value: Double, range: ClosedRange<Double>, fallback: Double) -> Double in
      return value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
   }
   var areas: [String: AreaValue] = [:]

   if name.isEmpty {
      return nil
   }
   for (key, value) in preset.areas ?? [:] where AREAS.contains(where: { (a) in return a.key == key }) && key != "plugins" {
      let mode = (Int(AREA_MODE_OVERALL)...Int(AREA_MODE_ORIGINAL)).contains(value.mode) ? value.mode : Int(AREA_MODE_OVERALL)

      areas[key] = AreaValue(mode: mode, surfaceMax: keep(value.surfaceMax, SURFACE_RANGE, SURFACE_MAX_DEFAULT),
         gamma: keep(value.gamma, GAMMA_RANGE, GAMMA_DEFAULT))
   }
   return SavedPreset(name: name, surfaceMax: keep(preset.surfaceMax, SURFACE_RANGE, SURFACE_MAX_DEFAULT),
      gamma: keep(preset.gamma, GAMMA_RANGE, GAMMA_DEFAULT), areas: areas,
      look: preset.look == Int(LOOK_LOGIC12) ? Int(LOOK_LOGIC12) : nil)
}

/**
 * Asks where to save a preset and writes it as a preset file.
 *
 * @param preset SavedPreset - the preset to share
 */
@MainActor
func exportPreset(_ preset: SavedPreset) {
   let panel = NSSavePanel()

   panel.title = "Export Preset"
   panel.message = "Save \"\(preset.name)\" as a file you can share."
   panel.allowedContentTypes = [ .json ]
   panel.nameFieldStringValue = preset.name.replacingOccurrences(of: "/", with: "-") + PRESET_FILE_SUFFIX
   guard panel.runModal() == .OK, let url = panel.url else {
      return
   }
   let encoder = JSONEncoder()

   encoder.outputFormatting = [ .prettyPrinted, .sortedKeys ]
   do {
      try encoder.encode(PresetFile(brightMeUpPreset: PRESET_FILE_FORMAT, preset: preset)).write(to: url, options: .atomic)
   } catch {
      showPresetError("BrightMeUp could not save the preset file. Please try another folder.")
   }
}

/**
 * Asks for a preset file and reads it.
 *
 * @return SavedPreset? - the preset in the file, or nil if the user cancelled or the file is not a preset
 */
@MainActor
func importPreset() -> SavedPreset? {
   let panel = NSOpenPanel()

   panel.title = "Load Preset"
   panel.message = "Choose a BrightMeUp preset file."
   panel.allowedContentTypes = [ .json ]
   panel.allowsMultipleSelection = false
   guard panel.runModal() == .OK, let url = panel.url else {
      return nil
   }
   let size = (try? url.resourceValues(forKeys: [ .fileSizeKey ]))?.fileSize ?? 0

   guard size > 0, size <= PRESET_FILE_MAX_BYTES, let data = try? Data(contentsOf: url),
      let file = try? JSONDecoder().decode(PresetFile.self, from: data), file.brightMeUpPreset >= 1,
      let preset = sanitized(file.preset) else {
      showPresetError("This file is not a BrightMeUp preset.")
      return nil
   }
   return preset
}

@MainActor
func showPresetError(_ message: String) {
   let alert = NSAlert()

   alert.messageText = message
   alert.alertStyle = .warning
   alert.runModal()
}
