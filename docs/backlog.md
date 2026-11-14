# Backlog

Every task Adi gives is tracked here and in Linear (project "BrightMeUp"). IDs (BL-01, BL-02...) are never reused.
Priority: **P1** this week, **P2** next, **P3** someday. Severity: **Critical**, **High**, **Medium**, **Low**.
Layout (2026-10-13): `- [ ]` open in **Inbox**, `- [~]` in progress in **Now**, `- [x]` finished in **Done** (newest first, with the date), `- [-]` dropped (with the reason, stays where it was). Every line is `- [ ] **BL-n** [LINK] `P1 · High` **Title:** what and why`; the link appears after `--send`. Nothing is ever deleted from this file.
After adding an item run `node ~/.claude/scripts/backlog-linear.mjs --send`; `--start BL-n` when work begins, `--done BL-n` when it is finished, `--drop BL-n "why"` to drop it.

## Inbox






## Now

## Done

- [x] **BL-5** `P1 · Medium` **Resizable window and area previews:** let the app window resize and go full screen, and add live previews for the Mixer, Piano Roll, a plug-in and the main window (control bar and inspector), switching the preview to the area being edited. Adi asked 2026-11-14. Shipped as 1.2.0, with the copyright line changed to InPlug/AGsoundtrax LLC. · done 2026-11-14

- [x] **BL-4** `P2 · Low` **Bigger footer with copyright:** make "Powered by InPlug.app" bigger and add "© 2026 InPlug. All rights reserved." Adi asked 2026-11-14. Shipped as 1.1.2. · done 2026-11-14

- [x] **BL-3** `P2 · Low` **Powered by InPlug.app footer:** a small "Powered by InPlug.app" line at the bottom of the app that opens https://inplug.app. Adi asked 2026-11-14. Shipped as 1.1.1. · done 2026-11-14

- [x] **BL-2** `P1 · High` **Per-area control and many presets:** let the user set lightness and contrast separately for each part of Logic Pro (tracks, mixer, editors, inspector, browsers, control bar, windows), or keep a part dark, and ship a large preset library. Adi asked 2026-11-14. Shipped as 1.1.0: 8 areas (Overall / Custom / Original each), 30 presets in 6 groups, presets save areas. · done 2026-11-14

- [x] **BL-1** `P1 · High` **Make BrightMeUp our own Mac app:** take the MIT-licensed i-see-logic-pro light theme for Logic Pro, rebrand it as BrightMeUp (name, bundle id, icon, docs), build it and put the app in Applications. Adi asked 2026-11-14. Also: 6 presets, saved presets, Reset to Default, fine steps, Before/After preview, Developer ID signed and notarized. · done 2026-11-14
