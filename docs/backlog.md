# Backlog

Every task Adi gives is tracked here and in Linear (project "BrightMeUp"). IDs (BL-01, BL-02...) are never reused.
Priority: **P1** this week, **P2** next, **P3** someday. Severity: **Critical**, **High**, **Medium**, **Low**.
Layout (2026-10-13): `- [ ]` open in **Inbox**, `- [~]` in progress in **Now**, `- [x]` finished in **Done** (newest first, with the date), `- [-]` dropped (with the reason, stays where it was). Every line is `- [ ] **BL-n** [LINK] `P1 · High` **Title:** what and why`; the link appears after `--send`. Nothing is ever deleted from this file.
After adding an item run `node ~/.claude/scripts/backlog-linear.mjs --send`; `--start BL-n` when work begins, `--done BL-n` when it is finished, `--drop BL-n "why"` to drop it.

## Inbox
















## Now

- [~] **BL-22** `P0 · Urgent` **ChromaVerb graph turned light:** the graph area inside ChromaVerb (and other plug-ins with graphs: EnVerb, Channel EQ, Tremolo, Ensemble, ADSR) was lightened, because MAVectorUIKit, which draws those graphs, was missing from the plug-in list. Add it so plug-ins stay stock. Real cause (found after 1.3.3): the theme also mapped 2276 colors from the plug-in color catalog (MAPlugInGUISwift), e.g. WhiteReverbPluginDisplayBackground. 1.3.4 never maps plug-in catalog colors. Adi reported 2026-11-14.

- [~] **BL-18** `P1 · High` **Null test:** prove the audio is identical with and without BrightMeUp by comparing two bounces sample by sample. Adi asked 2026-11-14. tools/null-test.sh written and self-tested; needs two bounces of the same project (stock and BrightMeUp).

- [~] **BL-17** `P1 · High` **Release gate:** a script that launches Logic Pro with the theme on a test project, checks plug-in windows, playback and crash reports, and must pass before any release. Adi asked 2026-11-14. tools/release-check.sh written; needs the test project (Manzana copy saved with plug-in windows open) and a run with Logic Pro closed.


## Done

- [x] **BL-21** `P2 · Medium` **Update notice and one-click update from GitHub:** on launch the app checks the latest GitHub release; if newer, a bar offers Update Now (download, verify our Developer ID signature, replace, relaunch), What's New and Later. Fails silently; never touches the theme. Also BrightMeUp > Check for Updates... in the menu, which always answers. Every release goes to GitHub with BrightMeUp.dmg and BrightMeUp.zip. Adi asked 2026-11-14. Published as v1.3.2. · done 2026-11-14

- [x] **BL-20** `P2 · Medium` **README: tested only with Logic Pro 13, in bold:** under the download button and in Requirements. Adi asked 2026-11-14. · done 2026-11-14

- [x] **BL-19** `P3 · Low` **Version next to the title, and 1.3.0:** show the app version under the BrightMeUp title, and number the safety release 1.3.0. Adi asked 2026-11-14. Published as v1.3.0 after Adi tested it ("working"). · done 2026-11-14

- [x] **BL-16** `P1 · High` **Safety: never act on audio threads:** every hook does nothing on real-time (audio) threads, and test mode counts any such call. Adi asked 2026-11-14. Done in 1.2.6: isRealtimeThread() in every hook, unit tested with a real-time thread. · done 2026-11-14

- [x] **BL-15** `P1 · High` **Safety: turn off on anything unexpected:** at launch the theme checks every class and method it relies on (plug-in windows included); if anything is missing it installs nothing and Logic Pro runs stock, and the app says why. Adi asked 2026-11-14. Done in 1.2.6: missingPart() check, app shows when the theme turned itself off. Also fixed: plug-in protection was off at 100% Lightness. · done 2026-11-14

- [x] **BL-14** `P1 · Critical` **1.2.4 crashed Logic Pro at launch:** the new plug-in check asked AppKit for the drawing appearance during launch, AppKit called back into the appearance hook and stopped. Fixed in 1.2.5 (no check before the first plug-in window, no re-entry), tested with a real Logic Pro launch, 1.2.4 and 1.2.3 releases hidden. Adi reported 2026-11-14. · done 2026-11-14

- [x] **BL-13** `P1 · Critical` **Never touch plug-ins:** the theme also changed plug-in windows (built-in and third-party). Only the Logic Pro interface may change; every plug-in window must keep its own look. Adi reported 2026-11-14. Fixed in 1.2.4: plug-in windows keep the real dark look and every color/image hook skips them; plug-in area removed from the app. GitHub release v1.2.3 set to draft so the buggy build cannot be downloaded. Published as v1.2.4 on Adi's "push". · done 2026-11-14

- [x] **BL-12** `P3 · Low` **Remove the Credits line from the README:** Adi asked 2026-11-14. The LICENSE file keeps the original copyright notice, which the MIT license requires. · done 2026-11-14

- [x] **BL-11** `P2 · Medium` **Drag-and-drop DMG installer:** a beautiful DMG like InPlug's (custom background, big icons, arrow to Applications), signed and notarized. Adi asked 2026-11-14. tools/dmg/build.sh makes dist/BrightMeUp.dmg (sunrise background, "Drag it in. Brighten up."), notarized, attached to v1.2.3; README button now downloads the DMG. CLAUDE.md taken off GitHub (kept locally). · done 2026-11-14

- [x] **BL-10** `P1 · High` **Clean the README and push to GitHub:** rewrite the README to describe results only (no internals), replace the old launcher screenshot, then push to github.com/adigold/BrightMeUp. Adi asked 2026-11-14. README rewritten like CST-Convertor (Download for Mac button to releases/latest/download/BrightMeUp.zip), release v1.2.3 published. · done 2026-11-14

- [x] **BL-9** `P2 · Medium` **Animated GIF for the README:** an eye-catching animated GIF at the top of the GitHub README showing BrightMeUp turning Logic Pro light, the previews and presets. Adi asked 2026-11-14. docs/brightmeup.gif (13 s loop, 5.2 MB), rebuilt with tools/readme-gif/build.sh. · done 2026-11-14

- [x] **BL-8** `P1 · Medium` **Revert to Logic Defaults button:** a big button at the top right that asks "Are you sure?" and then restarts Logic Pro in its original look, without BrightMeUp. Adi asked 2026-11-14. Shipped as 1.2.3. · done 2026-11-14

- [x] **BL-7** `P1 · Medium` **Clearer launch status:** rewrite the status messages in plain words, and when Logic Pro is open offer a Restart Logic Pro button that quits it (Logic asks to save) and reopens it with the look. Adi asked 2026-11-14. Shipped as 1.2.2. · done 2026-11-14

- [x] **BL-6** `P1 · High` **Preview overflows the window:** the Piano Roll preview pushed the page wider than a small window, so content went off the left edge. Make every preview fit any window size. Adi reported 2026-11-14. Fixed in 1.2.1; all five previews checked at the smallest window size. · done 2026-11-14

- [x] **BL-5** `P1 · Medium` **Resizable window and area previews:** let the app window resize and go full screen, and add live previews for the Mixer, Piano Roll, a plug-in and the main window (control bar and inspector), switching the preview to the area being edited. Adi asked 2026-11-14. Shipped as 1.2.0, with the copyright line changed to InPlug/AGsoundtrax LLC. · done 2026-11-14

- [x] **BL-4** `P2 · Low` **Bigger footer with copyright:** make "Powered by InPlug.app" bigger and add "© 2026 InPlug. All rights reserved." Adi asked 2026-11-14. Shipped as 1.1.2. · done 2026-11-14

- [x] **BL-3** `P2 · Low` **Powered by InPlug.app footer:** a small "Powered by InPlug.app" line at the bottom of the app that opens https://inplug.app. Adi asked 2026-11-14. Shipped as 1.1.1. · done 2026-11-14

- [x] **BL-2** `P1 · High` **Per-area control and many presets:** let the user set lightness and contrast separately for each part of Logic Pro (tracks, mixer, editors, inspector, browsers, control bar, windows), or keep a part dark, and ship a large preset library. Adi asked 2026-11-14. Shipped as 1.1.0: 8 areas (Overall / Custom / Original each), 30 presets in 6 groups, presets save areas. · done 2026-11-14

- [x] **BL-1** `P1 · High` **Make BrightMeUp our own Mac app:** take the MIT-licensed i-see-logic-pro light theme for Logic Pro, rebrand it as BrightMeUp (name, bundle id, icon, docs), build it and put the app in Applications. Adi asked 2026-11-14. Also: 6 presets, saved presets, Reset to Default, fine steps, Before/After preview, Developer ID signed and notarized. · done 2026-11-14
