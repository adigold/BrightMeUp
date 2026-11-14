# The installer window, like InPlug's: a sunrise background with "Drag it in. Brighten up.",
# big icons, BrightMeUp on the left, Applications on the right, an arrow between them, no toolbar.
# Used by tools/dmg/build.sh: dmgbuild -s tools/dmg/settings.py -D app=... -D icon=... -D background=...
import os.path

app = defines["app"]
format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]
background = defines["background"]
# 545 points tall, so the whole picture shows even when Finder adds its path and status bars (Adi, 2026-11-14).
window_rect = ((200, 120), (660, 545))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
icon_size = 150
text_size = 13
icon_locations = {os.path.basename(app): (137, 245), "Applications": (523, 245)}
