// Checks GitHub for a newer BrightMeUp at launch and can install it in one click. It touches only
// the BrightMeUp app, never the theme or Logic Pro, and every failure is quiet: the app works the
// same without a network (Adi, 2026-11-14).
import AppKit
import SwiftUI

let RELEASES_API = URL(string: "https://api.github.com/repos/adigold/BrightMeUp/releases/latest")!
let RELEASES_PAGE = URL(string: "https://github.com/adigold/BrightMeUp/releases/latest")!
let UPDATE_ASSET = "BrightMeUp.zip"
// An update must be signed with this Developer ID team, or it is not installed.
let SIGNING_REQUIREMENT = "anchor apple generic and certificate leaf[subject.OU] = \"4HJV6RPCLU\""

struct UpdateInfo: Equatable {
   let version: String
   let download: URL
   let page: URL
}

/**
 * Compares two versions such as 1.3.1 and 1.10.0, number by number.
 *
 * @return Bool - true if candidate is newer than current
 */
func isNewer(_ candidate: String, than current: String) -> Bool {
   let parts = { (text: String) in
      return text.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { (part) in
         return Int(part) ?? 0
      }
   }
   let a = parts(candidate), b = parts(current)

   for i in 0..<max(a.count, b.count) {
      let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0

      if x != y {
         return x > y
      }
   }
   return false
}

/**
 * Runs a command and reports if it ended with code 0.
 */
func run(_ path: String, _ arguments: [String]) -> Bool {
   let process = Process()

   process.executableURL = URL(fileURLWithPath: path)
   process.arguments = arguments
   process.standardOutput = FileHandle.nullDevice
   process.standardError = FileHandle.nullDevice
   do {
      try process.run()
      process.waitUntilExit()
   } catch {
      return false
   }
   return process.terminationStatus == 0
}

@MainActor
final class Updater: ObservableObject {
   enum State: Equatable {
      case idle, checking, available(UpdateInfo), upToDate, unreachable, updating, failed(UpdateInfo, String)
   }

   // One updater for the window and the Check for Updates menu item.
   static let shared = Updater()

   @Published var state = State.idle
   @Published var isDismissed = false

   var current: String {
      return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
   }

   /**
    * Asks GitHub for the latest release. The check at launch says nothing when there is no newer
    * one or no network; a check from the menu always answers.
    *
    * @param isManual Bool - true when the user chose Check for Updates
    */
   func check(isManual: Bool = false) async {
      var request = URLRequest(url: RELEASES_API, timeoutInterval: 15)

      if isManual {
         isDismissed = false
         state = .checking
      }

      request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
      request.setValue("BrightMeUp/\(current)", forHTTPHeaderField: "User-Agent")
      guard let (data, response) = try? await URLSession.shared.data(for: request),
         (response as? HTTPURLResponse)?.statusCode == 200,
         let release = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let tag = release["tag_name"] as? String,
         let assets = release["assets"] as? [[String: Any]],
         let asset = assets.first(where: { (a) in return a["name"] as? String == UPDATE_ASSET }),
         let link = asset["browser_download_url"] as? String, let download = URL(string: link) else {
         if isManual {
            state = .unreachable
         }
         return
      }
      let page = (release["html_url"] as? String).flatMap(URL.init(string:)) ?? RELEASES_PAGE
      let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

      if isNewer(version, than: current) {
         state = .available(UpdateInfo(version: version, download: download, page: page))
      } else if isManual {
         state = .upToDate
      }
   }

   /**
    * Downloads the update, checks that it is our signed app and newer, swaps it in for this app
    * and opens it. On any failure this app stays as it is.
    */
   func install(_ info: UpdateInfo) async {
      let target = Bundle.main.bundleURL

      state = .updating
      let result: String? = await Task.detached(priority: .userInitiated) { () -> String? in
         let fm = FileManager.default
         let work = fm.temporaryDirectory.appendingPathComponent("BrightMeUp-update-\(UUID().uuidString)")
         let zip = work.appendingPathComponent(UPDATE_ASSET)
         let fresh = work.appendingPathComponent("BrightMeUp.app")

         defer {
            try? fm.removeItem(at: work)
         }
         do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let (file, response) = try await URLSession.shared.download(from: info.download)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
               return "The download did not finish."
            }
            try fm.moveItem(at: file, to: zip)
         } catch {
            return "The download did not finish."
         }
         guard run("/usr/bin/ditto", [ "-x", "-k", zip.path, work.path ]), fm.fileExists(atPath: fresh.path) else {
            return "The download could not be opened."
         }
         guard run("/usr/bin/codesign", [ "--verify", "--deep", "--strict", "-R=\(SIGNING_REQUIREMENT)", fresh.path ]) else {
            return "The download is not signed by BrightMeUp, so it was not installed."
         }
         let version = Bundle(url: fresh)?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

         guard isNewer(version, than: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") else {
            return "The download is not newer than this version."
         }
         do {
            _ = try fm.replaceItemAt(target, withItemAt: fresh, backupItemName: nil, options: [])
         } catch {
            return "BrightMeUp could not replace itself. Please download the update from GitHub."
         }
         return nil
      }.value
      if let result {
         state = .failed(info, result)
         return
      }
      // Opens the new copy once this one has quit.
      let relaunch = Process()

      relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
      relaunch.arguments = [ "-c", "sleep 1; /usr/bin/open \"$0\"", target.path ]
      try? relaunch.run()
      NSApp.terminate(nil)
   }
}

/**
 * The bar at the top of the window that offers a new version.
 */
struct UpdateBar: View {
   @ObservedObject var updater: Updater

   var body: some View {
      switch updater.state {
      case .available(let info) where !updater.isDismissed:
         bar(symbol: "arrow.down.circle.fill", text: "BrightMeUp \(info.version) is available. You have \(updater.current).") {
            Button("What's New") { NSWorkspace.shared.open(info.page) }
            Button("Later") { updater.isDismissed = true }
            Button("Update Now") { Task { await updater.install(info) } }
               .buttonStyle(.borderedProminent)
         }
      case .checking:
         bar(symbol: "arrow.triangle.2.circlepath", text: "Checking for updates...") {
            ProgressView().controlSize(.small)
         }
      case .upToDate:
         bar(symbol: "checkmark.circle.fill", text: "You have the latest version, BrightMeUp \(updater.current).") {
            Button("OK") { updater.state = .idle }
         }
      case .unreachable:
         bar(symbol: "wifi.exclamationmark", text: "BrightMeUp could not reach GitHub to check for updates. Check your internet connection and try again.") {
            Button("OK") { updater.state = .idle }
            Button("Open GitHub") { NSWorkspace.shared.open(RELEASES_PAGE) }
         }
      case .updating:
         bar(symbol: "arrow.down.circle", text: "Downloading and installing the update...") {
            ProgressView().controlSize(.small)
         }
      case .failed(let info, let message):
         bar(symbol: "exclamationmark.triangle.fill", text: message) {
            Button("Later") { updater.state = .idle }
            Button("Download from GitHub") { NSWorkspace.shared.open(info.page) }
               .buttonStyle(.borderedProminent)
         }
      default:
         EmptyView()
      }
   }

   func bar<Buttons: View>(symbol: String, text: String, @ViewBuilder buttons: () -> Buttons) -> some View {
      return HStack(spacing: 10) {
         Image(systemName: symbol).foregroundStyle(.orange).font(.title3)
         Text(text).lineLimit(2)
         Spacer()
         buttons()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.orange.opacity(0.35)))
   }
}
