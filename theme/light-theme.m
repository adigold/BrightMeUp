// Light theme for Logic Pro, loaded with DYLD_INSERT_LIBRARIES. Changes nothing on disk.
// The launcher app stores surfaceMax and gamma in the SETTINGS_DOMAIN preferences.
// The environment variables LP_SURFACE_MAX and LP_GAMMA override them.
// LP_OUT and LP_DELAY enable the render test.
#import <AppKit/AppKit.h>
#import <stdatomic.h>
#import <mach/mach.h>
#import <mach/thread_policy.h>
#import <pthread.h>
#import <dlfcn.h>
#import <execinfo.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "gray-rule.h"

#define MAX_RANGES 256
#define ADDRESS_MASK 0x0000ffffffffffffULL
#define MAX_STACK_FRAMES 128
#define GRAY_SPREAD 0.12
#define SHADOW_LIMIT 0.1
#define TINT_SPREAD 0.2
#define OVERLAY_ALPHA_MAX 64
#define SLOT_LIGHTEN 0.55
#define WELL_FADE 0.35
#define NOTE_TEXT_MIN 0.5
#define ACCENT_DARKEN 0.4
#define COLOR_MATCH 0.005
#define PLAYHEAD_WHITE 0.3
#define REGION_OUTLINE_DARKEN 0.65
#define DRAW_IMAGE_MAX 256
#define KNOB_IMAGE_SIZE 25
#define VOLUME_IMAGE_HEIGHT 20
#define BUTTON_IMAGE_HEIGHT 23
#define BEVEL_SPREAD_MIN 0.2
#define BLACK_MAX 0.05
#define THUMB_GAIN 2.6
#define TEXT_GAMMA 1.3
#define TEXT_LEVEL_MAX 0.45
#define TEXT_ALPHA_GAMMA 0.45
#define SECONDARY_LABEL_ALPHA 0.72
#define TERTIARY_LABEL_ALPHA 0.5
#define SETTINGS_DOMAIN @SETTINGS_DOMAIN_NAME
#define LOGIC_BUNDLE_ID @"com.apple.logic10"
// The color list cache, one file for each Logic Pro build, below the home folder.
#define COLOR_CACHE_DIR @"Library/Caches/com.adigoldstein.brightmeup"
#define ASSETUTIL_PATH @"/usr/bin/assetutil"
#define FIELD_DARK_MAX 0.5
#define PLATTER_ALPHA 0.35

// A pale blue, because list text is black in this theme.
static const CGFloat FOCUSED_ROW_COLOR[3] = { 0.72, 0.84, 0.96 };

typedef struct { uintptr_t start; uintptr_t end; } ImageRange;
typedef enum { STYLE_PLAIN, STYLE_SLOT, STYLE_WELL, STYLE_KNOB, STYLE_THUMB, STYLE_WHITE } ImageStyle;

static ImageRange logicRanges[MAX_RANGES];
static volatile int logicRangeCount = 0;
// The code of plug-in interfaces: Logic's own plug-in GUI frameworks and every third-party plug-in.
// Colors, images and appearances that this code asks for are never changed.
static ImageRange pluginRanges[MAX_RANGES];
static volatile int pluginRangeCount = 0;
static const char *const PLUGIN_PATHS[] = { "/MAPlugInGUI.framework/", "/MAPlugInGUISwift.framework/", "/MAAlchemy.framework/",
   "/MAGenerativeInstrumentsUI.framework/", "/MADSP.framework/", "/MADSPCore.framework/",
   "/MADSPPlugInPublic.framework/", "/MAResourcesPlugInsShared.framework/", "/MAVectorUIKit.framework/", "/Audio/Plug-Ins/", ".component/", ".vst3/", ".vst/", ".appex/" };
static double grayGamma = GAMMA_DEFAULT;
static double surfaceMax = SURFACE_MAX_DEFAULT;

// The areas of Logic Pro, in the order of AREA_KEYS. AREA_WINDOWS takes every other color.
typedef enum { AREA_TRACKS, AREA_MIXER, AREA_EDITORS, AREA_CONTROL_BAR, AREA_INSPECTOR, AREA_BROWSERS, AREA_PLUGINS, AREA_WINDOWS, AREA_COUNT } Area;
static NSString *const AREA_KEYS[AREA_COUNT] = { @"tracks", @"mixer", @"editors", @"controlbar", @"inspector", @"browsers", @"plugins", @"windows" };
typedef struct { int mode; double surfaceMax; double gamma; } AreaSetting;
static AreaSetting areaSettings[AREA_COUNT];
static NSAppearance *trueAqua;
// The real dark appearance, which plug-in windows keep. Nothing else in Logic Pro uses it.
static NSAppearance *trueDarkAqua;
// Its own light appearance object for every dark request the theme answers with light. Inside a
// plug-in window any view holding it is set back to the real dark appearance, so a plug-in that
// asks for dark always gets dark (Adi, 2026-11-14: never touch a plug-in).
static NSAppearance *mappedAqua;
static CGColorSpaceRef srgbSpace;
static NSString *outDir;
static int recoloredImages = 0;
static uintptr_t regionDrawStart, regionDrawEnd;
static ImageRange panKnobDraw, arrangeKnobDraw, trackHeaderDraw, textDraw, rulerMarkerDraw, threePartDraw;
static CGColorRef (*fillColorOf)(CGContextRef);

/**
 * Records the __TEXT range of images inside the Logic Pro bundle.
 *
 * @param header const struct mach_header * - the image that was added
 * @param slide intptr_t - the image slide (not used)
 */
static void addImage(const struct mach_header *header, intptr_t slide) {
   Dl_info info;
   const struct load_command *cmd = (const void *)((const struct mach_header_64 *)header + 1);

   BOOL isLogic, isPlugin = NO;

   if (!dladdr(header, &info) || !info.dli_fname) {
      return;
   }
   isLogic = strstr(info.dli_fname, "/Logic Pro.app/") != NULL && logicRangeCount < MAX_RANGES;
   for (size_t i = 0; i < sizeof(PLUGIN_PATHS) / sizeof(PLUGIN_PATHS[0]); i++) {
      isPlugin = isPlugin || strstr(info.dli_fname, PLUGIN_PATHS[i]) != NULL;
   }
   isPlugin = isPlugin && pluginRangeCount < MAX_RANGES;
   if (!isLogic && !isPlugin) {
      return;
   }
   for (uint32_t i = 0; i < header->ncmds; i++) {
      const struct segment_command_64 *seg = (const void *)cmd;

      if (cmd->cmd == LC_SEGMENT_64 && strcmp(seg->segname, "__TEXT") == 0) {
         ImageRange range = { (uintptr_t)header, (uintptr_t)header + seg->vmsize };

         // Fill the entry before the count grows, so a reader on another thread never sees an empty one.
         if (isLogic) {
            logicRanges[logicRangeCount] = range;
            atomic_thread_fence(memory_order_release);
            logicRangeCount += 1;
         }
         if (isPlugin) {
            pluginRanges[pluginRangeCount] = range;
            atomic_thread_fence(memory_order_release);
            pluginRangeCount += 1;
         }
         return;
      }
      cmd = (const void *)((const char *)cmd + cmd->cmdsize);
   }
}

// ponytail: linear scan of about 70 ranges per color request, sort if profiling shows a cost
static BOOL isPluginCaller(void *address) {
   uintptr_t pc = (uintptr_t)address & ADDRESS_MASK;
   int count = pluginRangeCount;

   atomic_thread_fence(memory_order_acquire);
   for (int i = 0; i < count; i++) {
      if (pc >= pluginRanges[i].start && pc < pluginRanges[i].end) {
         return YES;
      }
   }
   return NO;
}

// Walks the stack (addresses only, no symbol lookup). Used only where calls are rare.
static BOOL isPluginOnStack(void) {
   void *frames[32];
   int depth = backtrace(frames, 32);

   for (int i = 0; i < depth; i++) {
      if (isPluginCaller(frames[i])) {
         return YES;
      }
   }
   return NO;
}

static BOOL isLogicCaller(void *address) {
   uintptr_t pc = (uintptr_t)address & ADDRESS_MASK;

   for (int i = 0; i < logicRangeCount; i++) {
      if (pc >= logicRanges[i].start && pc < logicRanges[i].end) {
         return YES;
      }
   }
   return NO;
}

/**
 * Maps a gray level from the dark theme to the light theme.
 *
 * @param white CGFloat - gray level from 0 to 1
 * @param alpha CGFloat - opacity from 0 to 1
 * @return CGFloat - the new gray level
 */
static CGFloat mapGrayWith(CGFloat white, CGFloat alpha, double lightest, double gamma) {
   if (alpha < 1 && white < SHADOW_LIMIT) {
      return white;
   }
   return mapGrayLevel(white, lightest, gamma);
}

static CGFloat mapGray(CGFloat white, CGFloat alpha) {
   return mapGrayWith(white, alpha, surfaceMax, grayGamma);
}

static BOOL isGrayish(CGFloat r, CGFloat g, CGFloat b) {
   return (fmax(r, fmax(g, b)) - fmin(r, fmin(g, b))) < GRAY_SPREAD;
}

// Asset sets give these as literal colors: the pan fill, the input monitoring glyph, and the
// mute and solo glyphs in the intermediate state.
static const CGFloat DARKENED_LITERALS[][3] = { { 83.0 / 255, 215.0 / 255, 105.0 / 255 }, { 1, 0.623, 0.039 }, { 0.3, 1, 1 }, { 1, 0.8, 0 } };

static BOOL isDarkenedLiteral(CGFloat r, CGFloat g, CGFloat b) {
   for (size_t i = 0; i < sizeof(DARKENED_LITERALS) / sizeof(DARKENED_LITERALS[0]); i++) {
      const CGFloat *c = DARKENED_LITERALS[i];

      if (fabs(r - c[0]) < COLOR_MATCH && fabs(g - c[1]) < COLOR_MATCH && fabs(b - c[2]) < COLOR_MATCH) {
         return YES;
      }
   }
   return NO;
}

static IMP origCalWhite, origDevWhite, origWhite, origGenWhite;
static IMP origCalRGB, origDevRGB, origRGB, origSRGB;
static IMP origBlack, origWhiteColor, origDarkGray, origLightGray, origGray;

static char mappedKey, bevelKey, whiteKey;
static BOOL isOnBevel;
static CGRect coloredBevel;
static NSSet<NSString *> *singleAppearanceNames;
static IMP origCompositeImage, origCatalogImage, origImageDraw, origRepDraw, origBestRep;
static IMP origCGColor, origAppearanceNamed, origAppSetAppearance;
static IMP origTooltipLabel, origTooltipValue, origTooltipRightValue;
static IMP origAdjustDarkText, origSetCaretColor, origSetTypingAttributes;
static IMP origNibDecode, origAppearanceDecode, origHeaderDraw, origToolbarImage, origButtonImage;
static IMP origOrderWindow, origClipBackground, origFieldBackground, origPlatterLayout;
static NSColor *scaledControlBackground;
static Ivar toolbarOnColor;
static Class notesTextView;

static BOOL isTransportText(NSString *name) {
   BOOL isTransport = [name hasPrefix:@"TransportDisplay"] || [name hasPrefix:@"Colors/TransportDisplay/"];

   if (!isTransport || [name containsString:@"Background"]) {
      return NO;
   }
   return [name containsString:@"Fill"] || [name containsString:@"Label"] || [name containsString:@"Text"];
}

static BOOL isTextLabel(NSString *name) {
   return [name hasPrefix:@"TextLabel"] || [name hasPrefix:@"TextValue"] || [name hasPrefix:@"MixerSlotLabels"]
      || [name isEqualToString:@"MixerTypeAndNumberLabels"] || [name isEqualToString:@"MixerLevelNumbers"];
}

// These accents were chosen for dark surfaces. Peak values share the level meter colors.
static BOOL isAccent(NSString *name) {
   return [@[ @"MixerAutomationReadOnDefault", @"MixerLevelmeterGreen", @"MixerLevelmeterYellow", @"MixerKnobFillPan", @"TextLabelRed", @"TextLabelRedLighter", @"PlayheadLineSolo", @"PlayheadLineScore" ] containsObject:name];
}

// Translucent black reads as a recess on a dark surface, and as a heavy block on a light one.
static BOOL isWell(NSString *name) {
   return [name hasPrefix:@"MixerContainer"] || [@[ @"MixerLevelmeterBackground", @"MixerFaderTrack", @"MixerKnobTrack", @"MixerSliderLevelValueReadout" ] containsObject:name];
}

// The gray mapping makes the selected row darker than the rows around it, and the playhead black.
static CGFloat fixedGray(NSString *name, double lightest) {
   if ([name isEqualToString:@"TrackHeaderBackgroundSelected"]) {
      return SELECTED_ROW_WHITE * lightest;
   }
   return [name isEqualToString:@"PlayheadLineNormal"] ? PLAYHEAD_WHITE : -1;
}

// These colors are for the bright Piano Roll and Tracks modes, so they are already light. Their
// grays only scale to the lightest gray of the theme.
static BOOL isBrightVariant(NSString *name) {
   return [name hasSuffix:@"_Bright"] || [name hasSuffix:@"BrightColor"];
}

static BOOL hasAnyPrefix(NSString *name, NSArray<NSString *> *prefixes) {
   for (NSString *prefix in prefixes) {
      if ([name hasPrefix:prefix]) {
         return YES;
      }
   }
   return NO;
}

/**
 * Finds the area of Logic Pro that a catalog color belongs to, from its name.
 *
 * @param fullName NSString * - the catalog color name
 * @return Area - the area, or AREA_WINDOWS for shared colors
 */
static Area areaOfColor(NSString *fullName) {
   NSString *name = [fullName hasPrefix:@"Colors/"] ? [fullName substringFromIndex:7] : fullName;

   if ([name containsString:@"Plugin"] || hasAnyPrefix(name, @[ @"Amp", @"Compressor", @"Stompbox", @"Vintage", @"Pepper", @"Mastering", @"Retro", @"QuickSampler", @"Teeth", @"Quincy", @"Tycho", @"Remix", @"Sculpture", @"Alchemy", @"ES1", @"ES2", @"Studio", @"BeatBreaker", @"DrumSynth", @"DPad", @"MPad", @"Pad", @"String", @"Tuner", @"Linear", @"Dolby", @"SampleAlchemy", @"StepFX", @"SessionPlayer", @"Generic", @"GraphPanel", @"Metering", @"Graph" ])) {
      return AREA_PLUGINS;
   }
   if ([name containsString:@"Controlbar"] || hasAnyPrefix(name, @[ @"Transport", @"Control", @"Jogwheel", @"TopBevel", @"NumPad", @"PageControl" ])) {
      return AREA_CONTROL_BAR;
   }
   if (hasAnyPrefix(name, @[ @"Mixer", @"HCS", @"VCS", @"CStrips", @"SStrips", @"Strips", @"Channelstrip", @"Knob" ])) {
      return AREA_MIXER;
   }
   if (hasAnyPrefix(name, @[ @"PianoRoll", @"Piano", @"Score", @"StepSequencer", @"Beats", @"Editor", @"ListEditor", @"Pitch", @"Transform", @"SmartTempo", @"CellEditor", @"KeyNote", @"ActiveEdit", @"SpotErase", @"GIEditor" ])) {
      return AREA_EDITORS;
   }
   if (hasAnyPrefix(name, @[ @"Inspector", @"Smartcontrols", @"Widget", @"MIDILearn" ])) {
      return AREA_INSPECTOR;
   }
   if (hasAnyPrefix(name, @[ @"Library", @"Browser", @"ContentBrowser", @"TWR", @"Tableview", @"Table", @"Preview", @"Assistant", @"Sub", @"NewTrackSheet", @"Tenzing", @"File", @"Loop", @"CNProject" ])) {
      return AREA_BROWSERS;
   }
   if (hasAnyPrefix(name, @[ @"TrackHeader", @"Track", @"Region", @"SPRegion", @"Arrange", @"Ruler", @"Playhead", @"Grid", @"Automation", @"Flex", @"Takes", @"GlobalTracks", @"OneTrack", @"Drop", @"LiveLoops", @"Freeze" ])) {
      return AREA_TRACKS;
   }
   return AREA_WINDOWS;
}

static CGColorRef copyMappedColorWith(CGColorRef color, NSString *name, double surfaceMax, double grayGamma);

/**
 * Returns a copy of a color mapped for the light theme, with the values of the area of the color.
 * Saturated colors do not change.
 *
 * @param color CGColorRef - the original color
 * @param name NSString * - the catalog color name
 * @return CGColorRef - a retained color, or NULL if the color does not change
 */
static CGColorRef copyMappedColor(CGColorRef color, NSString *name) {
   AreaSetting area = areaSettings[areaOfColor(name)];

   if (area.mode == AREA_MODE_ORIGINAL) {
      return NULL;
   }
   if (area.mode == AREA_MODE_CUSTOM) {
      return copyMappedColorWith(color, name, area.surfaceMax, area.gamma);
   }
   return copyMappedColorWith(color, name, surfaceMax, grayGamma);
}

// The parameters shadow the globals on purpose, so the body maps with the values of one area.
static CGColorRef copyMappedColorWith(CGColorRef color, NSString *name, double surfaceMax, double grayGamma) {
   CGColorRef rgb = CGColorCreateCopyByMatchingToColorSpace(srgbSpace, kCGRenderingIntentDefault, color, NULL);
   const CGFloat *c = rgb ? CGColorGetComponents(rgb) : NULL;
   CGColorRef mapped = NULL;

   if (c && CGColorGetNumberOfComponents(rgb) == 4) {
      CGFloat level = (c[0] + c[1] + c[2]) / 3;
      CGFloat spread = fmax(c[0], fmax(c[1], c[2])) - fmin(c[0], fmin(c[1], c[2]));

      if (isBrightVariant(name)) {
         if (spread < GRAY_SPREAD && surfaceMax < 1) {
            CGFloat values[4] = { c[0] * surfaceMax, c[1] * surfaceMax, c[2] * surfaceMax, c[3] };

            mapped = CGColorCreate(srgbSpace, values);
         }
      } else if ([name isEqualToString:@"AlternatingLinesSelectedFocused"]) {
         CGFloat values[4] = { FOCUSED_ROW_COLOR[0] * surfaceMax, FOCUSED_ROW_COLOR[1] * surfaceMax, FOCUSED_ROW_COLOR[2] * surfaceMax, c[3] };

         mapped = CGColorCreate(srgbSpace, values);
      } else if (fixedGray(name, surfaceMax) >= 0) {
         CGFloat gray = fixedGray(name, surfaceMax);
         CGFloat values[4] = { gray, gray, gray, c[3] };

         mapped = CGColorCreate(srgbSpace, values);
      } else if (isAccent(name)) {
         CGFloat values[4] = { c[0] * ACCENT_DARKEN, c[1] * ACCENT_DARKEN, c[2] * ACCENT_DARKEN, c[3] };

         mapped = CGColorCreate(srgbSpace, values);
      } else if (isWell(name)) {
         CGFloat values[4] = { 0, 0, 0, c[3] * WELL_FADE };

         mapped = CGColorCreate(srgbSpace, values);
      } else if (isTransportText(name) && spread < TINT_SPREAD) {
         // Keep the tint and move the level to a dark text value.
         CGFloat shift = fmin(TEXT_LEVEL_MAX, pow(1 - level, TEXT_GAMMA)) - level;
         CGFloat values[4] = { fmax(0, c[0] + shift), fmax(0, c[1] + shift), fmax(0, c[2] + shift), c[3] };

         mapped = CGColorCreate(srgbSpace, values);
      } else if (spread < GRAY_SPREAD) {
         CGFloat white = mapGrayWith(level, c[3], surfaceMax, grayGamma);
         CGFloat alpha = isTextLabel(name) ? pow(c[3], TEXT_ALPHA_GAMMA) : c[3];
         CGFloat values[4] = { white, white, white, alpha };

         mapped = CGColorCreate(srgbSpace, values);
      }
   }
   if (rgb) {
      CGColorRelease(rgb);
   }
   return mapped;
}

// The windows that show plug-ins, built in or third party. They keep the stock look (Adi, 2026-11-14:
// the theme changes the Logic Pro interface only, never a plug-in).
// Real classes in Logic.framework (checked with nm on build 7801).
static NSString *const PLUGIN_WINDOW_CLASSES[] = { @"CLgPluginWindow", @"LgHUDPluginWindow", @"MetaPluginWindow" };
static NSString *const PLUGIN_CONTROLLER_CLASSES[] = { @"LgPluginWindowController", @"MAPluginWindowChildWindowController", @"GzAudioUnitUIWindowController" };

/**
 * Reports if a window shows a plug-in, or belongs to one, such as a menu or a child window.
 *
 * @param window NSWindow * - the window
 * @return BOOL - true for a plug-in window
 */
static BOOL isPluginWindow(NSWindow *window) {
   for (NSWindow *w = window; w; w = w.parentWindow) {
      for (size_t i = 0; i < sizeof(PLUGIN_WINDOW_CLASSES) / sizeof(PLUGIN_WINDOW_CLASSES[0]); i++) {
         Class cls = NSClassFromString(PLUGIN_WINDOW_CLASSES[i]);

         if (cls && [w isKindOfClass:cls]) {
            return YES;
         }
      }
      for (size_t i = 0; i < sizeof(PLUGIN_CONTROLLER_CLASSES) / sizeof(PLUGIN_CONTROLLER_CLASSES[0]); i++) {
         Class cls = NSClassFromString(PLUGIN_CONTROLLER_CLASSES[i]);

         if (cls && [w.windowController isKindOfClass:cls]) {
            return YES;
         }
      }
   }
   return NO;
}

/**
 * Reports if AppKit is drawing inside a plug-in window. Plug-in windows keep the real dark
 * appearance, and every other window of Logic Pro is light, so the drawing appearance tells.
 *
 * @return BOOL - true while a plug-in window draws
 */
// Set when the first plug-in window opens. Until then no plug-in can draw, and the check below
// must not run: early in the launch, asking AppKit for the drawing appearance starts its appearance
// setup, which calls +appearanceNamed: back into the theme and stops Logic Pro (2026-11-14 crash).
static atomic_bool hasPluginWindow = false;
// Guards against the same kind of loop on one thread at any later time.
static __thread BOOL isCheckingPlugin = NO;

// Audio runs on real-time threads. The theme must never act there, so every hook checks the
// thread first (Adi, 2026-11-14). The answer is kept per thread, so the check costs one system
// call per thread. Test mode reports how many calls were skipped this way.
static __thread int threadKind = 0;
static __thread unsigned int callsSinceCheck = 0;
static _Atomic long realtimeSkips = 0;

static BOOL isRealtimeThread(void) {
   // The main thread draws the interface and is never an audio thread.
   if (pthread_main_np()) {
      return NO;
   }
   // A thread can become real-time after its first call, so a non-real-time answer is checked
   // again every 256 calls. A real-time answer is kept.
   if (threadKind == 0 || (threadKind == 1 && (++callsSinceCheck & 255) == 0)) {
      thread_time_constraint_policy_data_t policy;
      mach_msg_type_number_t count = THREAD_TIME_CONSTRAINT_POLICY_COUNT;
      // FALSE asks for the policy of this thread; TRUE would return the default policy.
      boolean_t isDefault = FALSE;
      kern_return_t result = thread_policy_get(pthread_mach_thread_np(pthread_self()), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, &count, &isDefault);

      // If the system cannot answer, treat the thread as real-time: doing nothing is the safe side.
      threadKind = result != KERN_SUCCESS || !isDefault ? 2 : 1;
   }
   if (threadKind == 2) {
      atomic_fetch_add_explicit(&realtimeSkips, 1, memory_order_relaxed);
      return YES;
   }
   return NO;
}

static BOOL isPluginDrawing(void);

// True when a hook must leave everything as it is: on an audio thread, or inside a plug-in window.
static BOOL shouldSkip(void) {
   return isRealtimeThread() || isPluginDrawing();
}

static BOOL isPluginDrawing(void) {
   NSAppearance *current;
   BOOL result;

   if (!atomic_load_explicit(&hasPluginWindow, memory_order_acquire) || isCheckingPlugin) {
      return NO;
   }
   isCheckingPlugin = YES;
   current = NSAppearance.currentDrawingAppearance;
   result = current == trueDarkAqua || [current.name isEqualToString:NSAppearanceNameDarkAqua];
   isCheckingPlugin = NO;
   return result;
}

static CGColorRef realCGColor(id named) {
   return ((CGColorRef (*)(id, SEL))origCGColor)(named, @selector(cgColor));
}

/**
 * Returns the mapped color for Logic catalog colors that have one appearance. AppKit and
 * SwiftUI both read catalog colors here. Each color instance is mapped once.
 *
 * @param named id - the CUINamedColor instance
 * @param sel SEL - the cgColor selector
 * @return CGColorRef - the color to draw with
 */
static CGColorRef hookCGColor(id named, SEL sel) {
   id tag;
   CGColorRef mapped;

   // A plug-in can reach a catalog color through AppKit, so after the first plug-in window the
   // whole stack is checked too (Adi, 2026-11-14: ChromaVerb graph).
   if (shouldSkip() || isPluginCaller(__builtin_return_address(0)) || (atomic_load_explicit(&hasPluginWindow, memory_order_acquire) && isPluginOnStack())) {
      return realCGColor(named);
   }
   tag = objc_getAssociatedObject(named, &mappedKey);

   if (!tag) {
      tag = [NSNull null];
      NSString *name = [named valueForKey:@"name"];

      if ([singleAppearanceNames containsObject:name]) {
         mapped = copyMappedColor(realCGColor(named), name);
         if (mapped) {
            tag = CFBridgingRelease(mapped);
         }
      }
      objc_setAssociatedObject(named, &mappedKey, tag, OBJC_ASSOCIATION_RETAIN);
   }
   if (tag != [NSNull null]) {
      return (__bridge CGColorRef)tag;
   }
   return realCGColor(named);
}

static NSAppearance *hookAppearanceNamed(id cls, SEL sel, NSAppearanceName name) {
   NSAppearanceName mapped = name;

   // No appearance query here: this hook runs inside AppKit's own appearance setup.
   if (isRealtimeThread() || isPluginCaller(__builtin_return_address(0))) {
      mapped = name;
   } else if ([name isEqualToString:NSAppearanceNameDarkAqua]) {
      mapped = NSAppearanceNameAqua;
   } else if ([name isEqualToString:NSAppearanceNameVibrantDark]) {
      mapped = NSAppearanceNameVibrantLight;
   }
   if (mappedAqua && mapped != name && [mapped isEqualToString:NSAppearanceNameAqua]) {
      return mappedAqua;
   }
   return ((NSAppearance *(*)(id, SEL, NSAppearanceName))origAppearanceNamed)(cls, sel, mapped);
}

static void hookAppSetAppearance(id app, SEL sel, NSAppearance *appearance) {
   ((void (*)(id, SEL, NSAppearance *))origAppSetAppearance)(app, sel, trueAqua);
}

#define WHITE_HOOK(fn, orig) \
   static NSColor *fn(id cls, SEL sel, CGFloat white, CGFloat alpha) { \
      CGFloat mapped = isLogicCaller(__builtin_return_address(0)) && !isPluginCaller(__builtin_return_address(0)) && !shouldSkip() ? mapGray(white, alpha) : white; \
      return ((NSColor *(*)(id, SEL, CGFloat, CGFloat))orig)(cls, sel, mapped, alpha); \
   }

#define RGB_HOOK(fn, orig) \
   static NSColor *fn(id cls, SEL sel, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { \
      if (shouldSkip() || isPluginCaller(__builtin_return_address(0))) { \
      } else if (isLogicCaller(__builtin_return_address(0)) && isGrayish(r, g, b)) { \
         r = g = b = mapGray((r + g + b) / 3, a); \
      } else if (isLogicCaller(__builtin_return_address(0)) && isDarkenedLiteral(r, g, b)) { \
         r *= ACCENT_DARKEN; \
         g *= ACCENT_DARKEN; \
         b *= ACCENT_DARKEN; \
      } \
      return ((NSColor *(*)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat))orig)(cls, sel, r, g, b, a); \
   }

#define NAMED_HOOK(fn, orig, white) \
   static NSColor *fn(id cls, SEL sel) { \
      if (isLogicCaller(__builtin_return_address(0)) && !isPluginCaller(__builtin_return_address(0)) && !shouldSkip()) { \
         return ((NSColor *(*)(id, SEL, CGFloat, CGFloat))origGenWhite)(cls, @selector(colorWithGenericGamma22White:alpha:), mapGray(white, 1), 1); \
      } \
      return ((NSColor *(*)(id, SEL))orig)(cls, sel); \
   }

WHITE_HOOK(hookCalWhite, origCalWhite)
WHITE_HOOK(hookDevWhite, origDevWhite)
WHITE_HOOK(hookWhite, origWhite)
WHITE_HOOK(hookGenWhite, origGenWhite)
RGB_HOOK(hookCalRGB, origCalRGB)
RGB_HOOK(hookDevRGB, origDevRGB)
RGB_HOOK(hookRGB, origRGB)
RGB_HOOK(hookSRGB, origSRGB)
NAMED_HOOK(hookBlack, origBlack, 0)
NAMED_HOOK(hookWhiteColor, origWhiteColor, 1)
NAMED_HOOK(hookDarkGray, origDarkGray, 1.0 / 3)
NAMED_HOOK(hookLightGray, origLightGray, 2.0 / 3)
NAMED_HOOK(hookGray, origGray, 0.5)

static IMP origSecondaryLabel, origTertiaryLabel;

static NSColor *hookSecondaryLabel(id cls, SEL sel) {
   if (shouldSkip()) {
      return ((NSColor *(*)(id, SEL))origSecondaryLabel)(cls, sel);
   }
   return [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:SECONDARY_LABEL_ALPHA];
}

static NSColor *hookTertiaryLabel(id cls, SEL sel) {
   if (shouldSkip()) {
      return ((NSColor *(*)(id, SEL))origTertiaryLabel)(cls, sel);
   }
   return [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:TERTIARY_LABEL_ALPHA];
}

/**
 * Recolors one premultiplied pixel of a track header knob to match the Mixer knob. The ring
 * is black, the cap is gray and the pointer is white.
 *
 * @param px uint8_t * - the RGBA pixel
 */
static void recolorKnobPixel(uint8_t *px) {
   uint8_t alpha = px[3];
   BOOL isWhite = px[0] * 10 >= alpha * 9;
   BOOL isBlack = px[0] * 10 < alpha;

   for (int c = 0; c < 3; c++) {
      if (isWhite) {
         px[c] = 0;
      } else if (isBlack) {
         px[c] = (uint8_t)(px[c] * WELL_FADE);
      } else {
         px[c] = (uint8_t)(px[c] + (alpha * surfaceMax - px[c]) * SLOT_LIGHTEN);
      }
   }
   if (isBlack) {
      px[3] = (uint8_t)(alpha * WELL_FADE);
   }
}

/**
 * Copies a CGImage with translucent white pixels changed to black at the same opacity. The
 * slot style also mixes other pixels toward white, the well style fades them, the knob style
 * recolors the parts of a track header knob, and the thumb style makes white pixels solid.
 *
 * @param image CGImageRef - the source image
 * @param style ImageStyle - the extra change to make
 * @return CGImageRef - a retained image, or NULL if no pixel changed
 */
static CGImageRef copyRecoloredImage(CGImageRef image, ImageStyle style) {
   size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image), count = 0;
   CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4, srgbSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
   CGImageRef result = NULL;
   uint8_t *px;

   if (!ctx) {
      return NULL;
   }
   CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), image);
   px = CGBitmapContextGetData(ctx);
   for (size_t i = 0; i < CGBitmapContextGetBytesPerRow(ctx) * height; i += 4) {
      uint8_t alpha = px[i + 3];

      // Premultiplied white has each channel close to alpha.
      if (style == STYLE_WHITE && alpha > 0) {
         px[i] = alpha;
         px[i + 1] = alpha;
         px[i + 2] = alpha;
         count += 1;
      } else if (style == STYLE_KNOB && alpha > 0) {
         recolorKnobPixel(px + i);
         count += 1;
      } else if (style == STYLE_THUMB) {
         if (px[i] * 10 >= alpha * 9) {
            for (int c = 0; c < 4; c++) {
               px[i + c] = (uint8_t)fmin(UINT8_MAX, px[i + c] * THUMB_GAIN);
            }
            count += 1;
         }
      } else if (alpha > 0 && alpha < OVERLAY_ALPHA_MAX && px[i] * 10 >= alpha * 9 && px[i + 1] * 10 >= alpha * 9 && px[i + 2] * 10 >= alpha * 9) {
         px[i] = 0;
         px[i + 1] = 0;
         px[i + 2] = 0;
         count += 1;
      } else if (style == STYLE_SLOT && alpha > 0) {
         for (int c = 0; c < 3; c++) {
            px[i + c] = (uint8_t)(px[i + c] + (alpha * surfaceMax - px[i + c]) * SLOT_LIGHTEN);
         }
         count += 1;
      } else if (style == STYLE_WELL && alpha > 0) {
         for (int c = 0; c < 4; c++) {
            px[i + c] = (uint8_t)(px[i + c] * WELL_FADE);
         }
         count += 1;
      }
   }
   if (count > 0) {
      result = CGBitmapContextCreateImage(ctx);
   }
   CGContextRelease(ctx);
   return result;
}

static NSBitmapImageRep *recoloredRep(NSImageRep *rep, ImageStyle style) {
   NSRect bounds = NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh);
   CGImageRef source = [rep CGImageForProposedRect:&bounds context:nil hints:nil];
   CGImageRef changed = source ? copyRecoloredImage(source, style) : NULL;
   NSBitmapImageRep *replacement;

   if (!changed) {
      return nil;
   }
   replacement = [[NSBitmapImageRep alloc] initWithCGImage:changed];
   replacement.size = rep.size;
   // The rep hook must not change a replacement a second time.
   objc_setAssociatedObject(replacement, &mappedKey, [NSNull null], OBJC_ASSOCIATION_RETAIN);
   CGImageRelease(changed);
   recoloredImages += 1;
   return replacement;
}

static NSImage *recoloredImage(NSImage *image, ImageStyle style) {
   NSImage *copy = nil;

   if (![image isKindOfClass:[NSImage class]] || image.isTemplate) {
      return image;
   }
   for (NSImageRep *rep in image.representations) {
      NSBitmapImageRep *replacement = recoloredRep(rep, style);

      if (!replacement) {
         continue;
      }
      if (!copy) {
         copy = [image copy];
         for (NSImageRep *old in copy.representations) {
            [copy removeRepresentation:old];
         }
      }
      [copy addRepresentation:replacement];
   }
   return copy ?: image;
}

/**
 * Applies recoloredImage to an asset. Asset builders return one image per button state in
 * nested dictionaries.
 *
 * @param asset id - an NSImage or a dictionary of assets
 * @param style ImageStyle - the extra change to make
 * @return id - the asset with images replaced
 */
static id recoloredAsset(id asset, ImageStyle style) {
   if ([asset isKindOfClass:[NSDictionary class]]) {
      NSMutableDictionary *copy = [asset mutableCopy];

      for (id key in [asset allKeys]) {
         copy[key] = recoloredAsset(asset[key], style);
      }
      return copy;
   }
   return recoloredImage(asset, style);
}

// Slot labels are dark in this theme, so the blue and green slots must be light.
static ImageStyle assetStyle(id description) {
   NSString *text = [NSString stringWithFormat:@"%@", description];

   if ([text containsString:@"mixer_insert_empty"] || [text containsString:@"mixer_insert_audio_empty"]) {
      return STYLE_WELL;
   }
   if ([text containsString:@"mixer_insert_audio"] || [text containsString:@"mixer_insert_midi"]) {
      return STYLE_SLOT;
   }
   if ([text containsString:@"mixer_send"] && ![text containsString:@"mixer_sendvolume"]) {
      return STYLE_SLOT;
   }
   for (NSString *well in @[ @"mixer_display", @"mixer_eq", @"mixer_levelmeter_bg", @"mixer_panner_stereo_bg" ]) {
      if ([text containsString:well]) {
         return STYLE_WELL;
      }
   }
   return STYLE_PLAIN;
}

/**
 * Returns the code range of a Logic function. The two symbols must be adjacent in Logic.
 *
 * @param first const char * - the symbol of the function
 * @param next const char * - the symbol after the function
 * @return ImageRange - the range, or an empty range if a symbol is missing
 */
static ImageRange functionRange(const char *first, const char *next) {
   uintptr_t start = (uintptr_t)dlsym(RTLD_DEFAULT, first), end = (uintptr_t)dlsym(RTLD_DEFAULT, next);

   return start && end ? (ImageRange){ start, end } : (ImageRange){ 0, 0 };
}

/**
 * Returns whether the call stack passes through one of two functions. This compares addresses,
 * because a symbol lookup with dladdr scans the Logic symbol table and takes about 30 ms.
 *
 * @param first ImageRange - a function
 * @param second ImageRange - a function, or an empty range
 * @return BOOL - YES if a frame is inside a function
 */
static BOOL isCalledFrom(ImageRange first, ImageRange second) {
   void *frames[MAX_STACK_FRAMES];
   int depth = backtrace(frames, MAX_STACK_FRAMES);

   for (int i = 0; i < depth; i++) {
      uintptr_t pc = (uintptr_t)frames[i] & ADDRESS_MASK;

      if ((pc >= first.start && pc < first.end) || (pc >= second.start && pc < second.end)) {
         return YES;
      }
   }
   return NO;
}

// Track header images have no name, so the size and the caller identify them. This runs once
// per image. The volume slider is the only 20 point high image in the track header.
static ImageStyle drawStyle(NSSize size) {
   BOOL isKnobSize = size.width == KNOB_IMAGE_SIZE && size.height == KNOB_IMAGE_SIZE;

   if (isKnobSize && isCalledFrom(panKnobDraw, arrangeKnobDraw)) {
      return STYLE_KNOB;
   }
   if (size.height == VOLUME_IMAGE_HEIGHT && isCalledFrom(trackHeaderDraw, (ImageRange){ 0, 0 })) {
      return size.width == VOLUME_IMAGE_HEIGHT ? STYLE_THUMB : STYLE_WELL;
   }
   return STYLE_PLAIN;
}

/**
 * Returns the recolored copy of a small image, made once per image. The track header draws
 * buttons from a C++ asset cache, so its images never pass through the asset builders.
 *
 * @param image NSImage * - the image that Logic is about to draw
 * @return NSImage * - the image to draw
 */
static NSImage *drawableImage(NSImage *image) {
   id tag;

   if (!image || image.size.width > DRAW_IMAGE_MAX || image.size.height > DRAW_IMAGE_MAX) {
      return image;
   }
   tag = objc_getAssociatedObject(image, &mappedKey);
   if (!tag) {
      tag = recoloredImage(image, drawStyle(image.size));
      objc_setAssociatedObject(image, &mappedKey, tag == image ? [NSNull null] : tag, OBJC_ASSOCIATION_RETAIN);
      return tag;
   }
   return tag == [NSNull null] ? image : tag;
}

typedef void (*ImageDraw)(id, SEL, NSRect, NSRect, NSCompositingOperation, CGFloat, BOOL, NSDictionary *);
typedef BOOL (*RepDraw)(id, SEL, NSRect, NSRect, NSCompositingOperation, CGFloat, BOOL, NSDictionary *);

static CGRect deviceRect(NSRect rect) {
   CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;

   return ctx ? CGContextConvertRectToDeviceSpace(ctx, rect) : rect;
}

/**
 * Returns whether a rep is a piece of a button with a colored fill, measured once per rep.
 * Drawing the rep into one pixel gives its average color.
 *
 * @param rep NSImageRep * - the rep
 * @return BOOL - YES if the rep is a colored bevel
 */
static BOOL isColoredBevel(NSImageRep *rep) {
   NSNumber *known = objc_getAssociatedObject(rep, &bevelKey);
   NSRect bounds = NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh);
   CGImageRef image;
   CGContextRef ctx;
   uint8_t *px;
   BOOL isColored;

   if (known || rep.size.height != BUTTON_IMAGE_HEIGHT) {
      return known.boolValue;
   }
   image = [rep CGImageForProposedRect:&bounds context:nil hints:nil];
   ctx = image ? CGBitmapContextCreate(NULL, 1, 1, 8, 4, srgbSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast) : NULL;
   if (!ctx) {
      return NO;
   }
   CGContextDrawImage(ctx, CGRectMake(0, 0, 1, 1), image);
   px = CGBitmapContextGetData(ctx);
   isColored = fmax(px[0], fmax(px[1], px[2])) - fmin(px[0], fmin(px[1], px[2])) > px[3] * BEVEL_SPREAD_MIN;
   CGContextRelease(ctx);
   objc_setAssociatedObject(rep, &bevelKey, @(isColored), OBJC_ASSOCIATION_RETAIN);
   return isColored;
}

/**
 * Returns whether a draw lands inside the current colored button, and ends the button if not.
 *
 * @param rect NSRect - the destination
 * @return BOOL - YES if the center of the destination is inside the button
 */
static BOOL isOverBevel(NSRect rect) {
   CGRect device = deviceRect(rect);
   BOOL isOver = CGRectContainsPoint(coloredBevel, CGPointMake(CGRectGetMidX(device), CGRectGetMidY(device)));

   isOnBevel = NO;
   if (!isOver) {
      coloredBevel = CGRectNull;
   }
   return isOver;
}

/**
 * Records a piece of a button. A segment separator is a gray piece, and it can come between the
 * fill and the glyph, so it keeps the button rectangle.
 *
 * @param rep NSImageRep * - the rep that the caller is about to draw
 * @param rect NSRect - the destination
 * @return BOOL - YES if the rep is a button piece
 */
static BOOL noteBevel(NSImageRep *rep, NSRect rect) {
   if (rep.size.height != BUTTON_IMAGE_HEIGHT) {
      return NO;
   }
   if (isColoredBevel(rep)) {
      CGRect device = deviceRect(rect);
      BOOL isSameButton = isOnBevel && fabs(CGRectGetMinY(coloredBevel) - CGRectGetMinY(device)) < 1;

      coloredBevel = isSameButton ? CGRectUnion(coloredBevel, device) : device;
      isOnBevel = YES;
   } else {
      isOnBevel = NO;
   }
   return YES;
}

/**
 * Returns the rep to draw. Active buttons keep their fill, so a glyph inside one must stay white.
 *
 * @param rep NSImageRep * - the rep that the caller is about to draw
 * @param shown NSImageRep * - the rep that the theme chose
 * @param rect NSRect - the destination
 * @return NSImageRep * - the rep to draw
 */
static NSImageRep *repOnBevel(NSImageRep *rep, NSImageRep *shown, NSRect rect) {
   id white;

   if (noteBevel(rep, rect) || !isOverBevel(rect)) {
      return shown;
   }
   white = objc_getAssociatedObject(rep, &whiteKey);
   if (!white) {
      white = recoloredRep(rep, STYLE_WHITE) ?: rep;
      objc_setAssociatedObject(rep, &whiteKey, white, OBJC_ASSOCIATION_RETAIN);
   }
   return white;
}

/**
 * Draws the recolored copy of a small image rep, made once per rep. MADrawingThreePartImage
 * draws the center of some buttons from the rep directly, so the NSImage hooks miss it.
 *
 * @param rep NSImageRep * - the rep that the caller is about to draw
 * @return BOOL - the result of the original draw method
 */
static BOOL hookRepDraw(NSImageRep *rep, SEL sel, NSRect rect, NSRect from, NSCompositingOperation op, CGFloat fraction, BOOL flipped, NSDictionary *hints) {
   NSImageRep *shown = rep;
   BOOL isSmall;

   if (shouldSkip()) {
      return ((RepDraw)origRepDraw)(rep, sel, rect, from, op, fraction, flipped, hints);
   }
   isSmall = rep.size.width <= DRAW_IMAGE_MAX && rep.size.height <= DRAW_IMAGE_MAX;
   if (isLogicCaller(__builtin_return_address(0)) && !isPluginCaller(__builtin_return_address(0)) && isSmall) {
      id tag = objc_getAssociatedObject(rep, &mappedKey);

      if (!tag) {
         tag = recoloredRep(rep, drawStyle(rep.size)) ?: [NSNull null];
         objc_setAssociatedObject(rep, &mappedKey, tag, OBJC_ASSOCIATION_RETAIN);
      }
      shown = tag == [NSNull null] ? rep : tag;
   }
   // Most button pieces and glyphs reach this method through NSImage, with an AppKit caller.
   if (isSmall) {
      shown = repOnBevel(rep, shown, rect);
   }
   return ((RepDraw)origRepDraw)(shown, sel, rect, from, op, fraction, flipped, hints);
}

static void hookImageDraw(NSImage *image, SEL sel, NSRect rect, NSRect from, NSCompositingOperation op, CGFloat fraction, BOOL flipped, NSDictionary *hints) {
   NSImage *shown = isLogicCaller(__builtin_return_address(0)) && !isPluginCaller(__builtin_return_address(0)) && !shouldSkip() ? drawableImage(image) : image;

   ((ImageDraw)origImageDraw)(shown, sel, rect, from, op, fraction, flipped, hints);
}

/**
 * Returns the best rep of the recolored copy of an image. MADrawingThreePartImage draws the
 * center piece from this rep, for example the 1 by 20 center of the track header volume slider.
 * The rep is an NSImageRepGeometryProxy, which has its own draw method, so the rep hook misses it.
 *
 * @param image NSImage * - the image
 * @return NSImageRep * - the rep to draw
 */
static NSImageRep *hookBestRep(NSImage *image, SEL sel, NSRect rect, NSGraphicsContext *context, NSDictionary *hints) {
   uintptr_t caller = (uintptr_t)__builtin_return_address(0) & ADDRESS_MASK;
   NSImage *shown = caller >= threePartDraw.start && caller < threePartDraw.end && !shouldSkip() ? drawableImage(image) : image;

   return ((NSImageRep *(*)(id, SEL, NSRect, id, id))origBestRep)(shown, sel, rect, context, hints);
}

static void interposeThreePart(NSRect frame, NSImage *start, NSImage *center, NSImage *end, BOOL vertical, NSCompositingOperation op, CGFloat fraction, BOOL flipped) {
   if (isLogicCaller(__builtin_return_address(0)) && !isPluginCaller(__builtin_return_address(0)) && !shouldSkip()) {
      start = drawableImage(start);
      center = drawableImage(center);
      end = drawableImage(end);
   }
   NSDrawThreePartImage(frame, start, center, end, vertical, op, fraction, flipped);
}

/**
 * Draws a path. CRegionUI::colorOfOutline() returns a fixed black, so no color hook sees the
 * region outline. The region draw functions reach this call through GC::drawPath and
 * GC::_renderPath, so the third return address identifies them. The outline becomes a dark
 * shade of the region fill.
 *
 * @param ctx CGContextRef - the drawing context
 * @param mode CGPathDrawingMode - the drawing mode
 */
static void interposeDrawPath(CGContextRef ctx, CGPathDrawingMode mode) {
   uintptr_t caller = 0;
   CGColorRef fill = NULL;
   size_t count = 0;

   if (isLogicCaller(__builtin_return_address(0)) && !shouldSkip()) {
      caller = (uintptr_t)__builtin_return_address(2) & ADDRESS_MASK;
   }
   if (caller >= regionDrawStart && caller < regionDrawEnd && fillColorOf) {
      fill = fillColorOf(ctx);
      count = fill ? CGColorGetNumberOfComponents(fill) : 0;
   }
   if (count == 4) {
      const CGFloat *c = CGColorGetComponents(fill);
      CGFloat values[4] = { c[0] * REGION_OUTLINE_DARKEN, c[1] * REGION_OUTLINE_DARKEN, c[2] * REGION_OUTLINE_DARKEN, c[3] };
      CGColorRef outline = CGColorCreate(srgbSpace, values);

      CGContextSaveGState(ctx);
      CGContextSetStrokeColorWithColor(ctx, outline);
      CGContextDrawPath(ctx, mode);
      CGContextRestoreGState(ctx);
      CGColorRelease(outline);
      return;
   }
   CGContextDrawPath(ctx, mode);
}

/**
 * Sets the fill color, and keeps text white on a colored button. The factory hooks turn this
 * text black, and Logic draws it right after the button.
 *
 * @param ctx CGContextRef - the drawing context
 * @param color CGColorRef - the fill color
 */
static void interposeFillColor(CGContextRef ctx, CGColorRef color) {
   const CGFloat *c = isOnBevel && color && !shouldSkip() ? CGColorGetComponents(color) : NULL;
   size_t count = c ? CGColorGetNumberOfComponents(color) : 0;

   if (count >= 2 && fmax(c[0], c[count > 2 ? count - 2 : 0]) < BLACK_MAX) {
      CGFloat values[4] = { 1, 1, 1, c[count - 1] };
      CGColorRef white = CGColorCreate(srgbSpace, values);

      CGContextSetFillColorWithColor(ctx, white);
      CGColorRelease(white);
      return;
   }
   CGContextSetFillColorWithColor(ctx, color);
}

/**
 * Draws a line of text, and maps the gray of the marker names in the ruler. Logic gives these
 * names a fixed white, so no color hook sees it. The text becomes a clip, and a fill in the
 * mapped gray paints the glyphs.
 *
 * @param line CTLineRef - the line of text
 * @param ctx CGContextRef - the drawing context
 */
static void interposeLineDraw(CTLineRef line, CGContextRef ctx) {
   uintptr_t caller = (uintptr_t)__builtin_return_address(0) & ADDRESS_MASK;
   CFArrayRef runs = NULL;
   CGColorRef text = NULL, rgb = NULL;
   const CGFloat *c = NULL;

   if (caller >= textDraw.start && caller < textDraw.end && !shouldSkip() && isCalledFrom(rulerMarkerDraw, (ImageRange){ 0, 0 })) {
      runs = CTLineGetGlyphRuns(line);
   }
   if (runs && CFArrayGetCount(runs) > 0) {
      text = (CGColorRef)CFDictionaryGetValue(CTRunGetAttributes(CFArrayGetValueAtIndex(runs, 0)), kCTForegroundColorAttributeName);
   }
   if (text) {
      rgb = CGColorCreateCopyByMatchingToColorSpace(srgbSpace, kCGRenderingIntentDefault, text, NULL);
      c = rgb && CGColorGetNumberOfComponents(rgb) == 4 ? CGColorGetComponents(rgb) : NULL;
   }
   if (c && isGrayish(c[0], c[1], c[2])) {
      CGFloat white = mapGray((c[0] + c[1] + c[2]) / 3, c[3]);
      CGFloat values[4] = { white, white, white, c[3] };
      CGColorRef mapped = CGColorCreate(srgbSpace, values);
      CGPoint end;

      CGContextSaveGState(ctx);
      CGContextSetTextDrawingMode(ctx, kCGTextClip);
      CTLineDraw(line, ctx);
      end = CGContextGetTextPosition(ctx);
      CGContextSetFillColorWithColor(ctx, mapped);
      CGContextFillRect(ctx, CGContextGetClipBoundingBox(ctx));
      CGContextRestoreGState(ctx);
      CGContextSetTextPosition(ctx, end.x, end.y);
      CGColorRelease(mapped);
      CGColorRelease(rgb);
      return;
   }
   if (rgb) {
      CGColorRelease(rgb);
   }
   CTLineDraw(line, ctx);
}

__attribute__((used, section("__DATA,__interpose"))) static struct { const void *replacement; const void *original; } interposeTable[] = {
   { (const void *)interposeFillColor, (const void *)CGContextSetFillColorWithColor },
   { (const void *)interposeThreePart, (const void *)NSDrawThreePartImage },
   { (const void *)interposeDrawPath, (const void *)CGContextDrawPath },
   { (const void *)interposeLineDraw, (const void *)CTLineDraw },
};

static id hookCompositeImage(id manager, SEL sel, id description, id context) {
   if (shouldSkip() || isPluginOnStack()) {
      return ((id (*)(id, SEL, id, id))origCompositeImage)(manager, sel, description, context);
   }
   return recoloredAsset(((id (*)(id, SEL, id, id))origCompositeImage)(manager, sel, description, context), assetStyle(description));
}

static id hookCatalogImage(id manager, SEL sel, id description, id context) {
   if (shouldSkip() || isPluginOnStack()) {
      return ((id (*)(id, SEL, id, id))origCatalogImage)(manager, sel, description, context);
   }
   return recoloredAsset(((id (*)(id, SEL, id, id))origCatalogImage)(manager, sel, description, context), assetStyle(description));
}

/**
 * Returns text attributes with the color changed to a gray level at the same opacity.
 *
 * @param attributes NSDictionary * - the text attributes
 * @param white CGFloat - the new gray level
 * @return NSDictionary * - the changed attributes
 */
static NSDictionary *attributesWithGray(NSDictionary *attributes, CGFloat white) {
   NSColor *color = attributes[NSForegroundColorAttributeName];
   NSMutableDictionary *copy = [attributes mutableCopy];

   if (!color) {
      return attributes;
   }
   copy[NSForegroundColorAttributeName] = [NSColor colorWithSRGBRed:white green:white blue:white alpha:color.alphaComponent];
   return copy;
}

// Help tags keep their black bubble, so their text must stay white.
#define TOOLTIP_HOOK(fn, orig) \
   static NSDictionary *fn(id view, SEL sel) { \
      NSDictionary *original = ((NSDictionary *(*)(id, SEL))orig)(view, sel); \
      return isRealtimeThread() ? original : attributesWithGray(original, 1); \
   }

TOOLTIP_HOOK(hookTooltipLabel, origTooltipLabel)
TOOLTIP_HOOK(hookTooltipValue, origTooltipValue)
TOOLTIP_HOOK(hookTooltipRightValue, origTooltipRightValue)

/**
 * Changes bright gray note text to black, after Logic has processed loaded or pasted text.
 * The dark theme stores notes as white text. Logic changes dark text to white when it loads a
 * note, so notes saved with this theme are still readable without it.
 *
 * @param view NSTextView * - the note text view
 * @param sel SEL - the adjustDarkText selector
 */
static void hookAdjustDarkText(NSTextView *view, SEL sel) {
   NSTextStorage *storage = view.textStorage;

   ((void (*)(id, SEL))origAdjustDarkText)(view, sel);
   if (isRealtimeThread()) {
      return;
   }
   [storage enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, storage.length) options:0 usingBlock:^(NSColor *color, NSRange range, BOOL *stop) {
      NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];

      if (rgb && isGrayish(rgb.redComponent, rgb.greenComponent, rgb.blueComponent) && rgb.brightnessComponent > NOTE_TEXT_MIN) {
         [storage addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:rgb.alphaComponent] range:range];
      }
   }];
}

// Logic sets the note caret and typing color from a color factory that the hooks do not see.
static void hookSetCaretColor(NSTextView *view, SEL sel, NSColor *color) {
   NSColor *shown = !isRealtimeThread() && [view isKindOfClass:notesTextView] ? [NSColor blackColor] : color;

   ((void (*)(id, SEL, NSColor *))origSetCaretColor)(view, sel, shown);
}

static void hookSetTypingAttributes(NSTextView *view, SEL sel, NSDictionary *attributes) {
   NSDictionary *shown = !isRealtimeThread() && [view isKindOfClass:notesTextView] ? attributesWithGray(attributes, 0) : attributes;

   ((void (*)(id, SEL, NSDictionary *))origSetTypingAttributes)(view, sel, shown);
}

typedef id __attribute__((ns_returns_retained)) (*CoderInit)(__attribute__((ns_consumed)) id, SEL, NSCoder *);

/**
 * Returns a component gray mapped for the light theme. Other colors do not change.
 *
 * @param color NSColor * - the original color
 * @param levelMax CGFloat - the highest gray level to map, from 0 to 1
 * @return NSColor * - the mapped color, or the original color
 */
static NSColor *mappedGrayColor(NSColor *color, CGFloat levelMax) {
   NSColor *rgb = color.type == NSColorTypeComponentBased ? [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] : nil;
   CGFloat level, white;

   if (!rgb || !isGrayish(rgb.redComponent, rgb.greenComponent, rgb.blueComponent)) {
      return color;
   }
   level = (rgb.redComponent + rgb.greenComponent + rgb.blueComponent) / 3;
   if (level > levelMax) {
      return color;
   }
   white = mapGray(level, rgb.alphaComponent);
   return [NSColor colorWithSRGBRed:white green:white blue:white alpha:rgb.alphaComponent];
}

/**
 * Decodes a nib object, and maps a literal gray cell color. Nib colors never reach the factory
 * hooks. Colors with other keys stay, because the transport progress bar turns black.
 *
 * @param decoder NSCoder * - the nib decoder
 * @param sel SEL - the decodeObjectForKey: selector
 * @param key NSString * - the key to decode
 * @return id - the object to use
 */
static id hookNibDecode(NSCoder *decoder, SEL sel, NSString *key) {
   id decoded = ((id (*)(id, SEL, NSString *))origNibDecode)(decoder, sel, key);

   if (isRealtimeThread() || isPluginOnStack()) {
      return decoded;
   }
   BOOL isCellColor = [key isEqualToString:@"NSTextColor"] || [key isEqualToString:@"NSBackgroundColor"];

   NSColor *mapped;

   if (!isCellColor || ![decoded isKindOfClass:[NSColor class]]) {
      return decoded;
   }
   mapped = mappedGrayColor(decoded, 1);
   if (mapped == decoded) {
      return decoded;
   }
   // A nib does not know its window yet, so the color decides when it draws: a plug-in window
   // gets the color from the nib, every other window gets the mapped color.
   return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
      BOOL isDark = [appearance.name isEqualToString:NSAppearanceNameDarkAqua];

      return isDark || isRealtimeThread() ? (NSColor *)decoded : mapped;
   }];
}

/**
 * Maps a literal gray text field background that Logic sets in code, for example the track
 * rename field. Only dark grays change, because a color from the factory hooks is already light.
 *
 * @param field NSTextField * - the text field
 * @param sel SEL - the setBackgroundColor: selector
 * @param color NSColor * - the new background color
 */
static void hookFieldBackground(NSTextField *field, SEL sel, NSColor *color) {
   NSColor *mapped = color;

   if (!shouldSkip() && isLogicCaller(__builtin_return_address(0)) && !isPluginCaller(__builtin_return_address(0)) && !isPluginWindow(field.window)) {
      mapped = mappedGrayColor(color, FIELD_DARK_MAX);
   }

   ((void (*)(id, SEL, NSColor *))origFieldBackground)(field, sel, mapped);
}

/**
 * Maps a dark appearance that a nib stores. Decoding skips +[NSAppearance appearanceNamed:].
 *
 * @param appearance NSAppearance * - the object being decoded
 * @param sel SEL - the initWithCoder: selector
 * @param coder NSCoder * - the decoder
 * @return id - the appearance to use
 */
static id __attribute__((ns_returns_retained)) hookAppearanceDecode(__attribute__((ns_consumed)) NSAppearance *appearance, SEL sel, NSCoder *coder) {
   NSAppearance *decoded = ((CoderInit)origAppearanceDecode)(appearance, sel, coder);

   if (isRealtimeThread() || isPluginOnStack()) {
      return decoded;
   }
   return [decoded.name isEqualToString:NSAppearanceNameDarkAqua] ? mappedAqua : decoded;
}

// AppKit blends the header with plus darker under VibrantLight, which paints a black bar.
static void hookHeaderDraw(NSView *view, SEL sel, NSRect rect) {
   if (!shouldSkip() && view.appearance != trueAqua && !isPluginWindow(view.window)) {
      view.appearance = trueAqua;
   }
   ((void (*)(id, SEL, NSRect))origHeaderDraw)(view, sel, rect);
}

/**
 * Returns a white copy of a glyph, made once per image.
 *
 * @param image NSImage * - the glyph
 * @return NSImage * - the white copy
 */
static NSImage *whiteGlyph(NSImage *image) {
   NSImage *white = objc_getAssociatedObject(image, &whiteKey);

   if (!white) {
      white = [NSImage imageWithSize:image.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
         [image drawInRect:rect];
         [[NSColor colorWithSRGBRed:1 green:1 blue:1 alpha:1] set];
         NSRectFillUsingOperation(rect, NSCompositingOperationSourceAtop);
         return YES;
      }];
      objc_setAssociatedObject(image, &whiteKey, white, OBJC_ASSOCIATION_RETAIN);
   }
   return white;
}

static BOOL isColored(NSColor *color) {
   NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];

   return rgb && !isGrayish(rgb.redComponent, rgb.greenComponent, rgb.blueComponent);
}

// Glyphs are tinted with label colors, which are black here. Active colored buttons keep their
// fill, so their glyphs must stay white. Neutral fills stay light, and need a dark glyph.
static void hookToolbarImage(NSButtonCell *cell, SEL sel, NSImage *image, NSRect frame, NSView *view) {
   BOOL isActive = !shouldSkip() && cell.state == NSControlStateValueOn && isColored(object_getIvar(cell, toolbarOnColor));

   ((void (*)(id, SEL, NSImage *, NSRect, NSView *))origToolbarImage)(cell, sel, isActive ? whiteGlyph(image) : image, frame, view);
}

// Inactive windows draw these buttons without the colored fill.
static void hookButtonImage(NSButtonCell *cell, SEL sel, NSImage *image, NSRect frame, NSButton *view) {
   BOOL isButton = !shouldSkip() && [view isKindOfClass:[NSButton class]] && view.window.isMainWindow && !isPluginWindow(view.window);
   BOOL isActive = isButton && cell.state == NSControlStateValueOn && isColored(view.bezelColor);

   ((void (*)(id, SEL, NSImage *, NSRect, NSView *))origButtonImage)(cell, sel, isActive ? whiteGlyph(image) : image, frame, view);
}

// The macOS 26 title bar is glass, which is white in Aqua. A transparent title bar shows the
// window background. The main window uses the mapped BackgroundViewControlbar color, but the
// editor windows use the system windowBackgroundColor, which the theme does not map.
/**
 * Gives every view in a plug-in window that holds the theme's light appearance the real dark
 * appearance back, so the plug-in draws exactly as in stock Logic Pro.
 *
 * @param view NSView * - the top of the view tree
 */
static void restorePluginAppearance(NSView *view) {
   if (!view) {
      return;
   }
   if (view.appearance == mappedAqua) {
      view.appearance = trueDarkAqua;
   }
   for (NSView *child in view.subviews) {
      restorePluginAppearance(child);
   }
}

static IMP origViewMoved, origViewSetAppearance;

static void hookViewMoved(NSView *view, SEL sel) {
   ((void (*)(id, SEL))origViewMoved)(view, sel);
   if (!isRealtimeThread() && view.window && isPluginWindow(view.window)) {
      restorePluginAppearance(view);
   }
}

static void hookViewSetAppearance(NSView *view, SEL sel, NSAppearance *appearance) {
   if (appearance == mappedAqua && !isRealtimeThread() && view.window && isPluginWindow(view.window)) {
      appearance = trueDarkAqua;
   }
   ((void (*)(id, SEL, NSAppearance *))origViewSetAppearance)(view, sel, appearance);
}

static void hookOrderWindow(NSWindow *window, SEL sel, NSWindowOrderingMode place, NSInteger other) {
   if (isRealtimeThread()) {
      ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))origOrderWindow)(window, sel, place, other);
      return;
   }
   // A plug-in window keeps the real dark appearance, so it and the plug-in inside look stock.
   if (place != NSWindowOut && isPluginWindow(window)) {
      atomic_store_explicit(&hasPluginWindow, true, memory_order_release);
      if (window.appearance != trueDarkAqua) {
         window.appearance = trueDarkAqua;
      }
      restorePluginAppearance(window.contentView.superview ?: window.contentView);
   } else if (surfaceMax < 1 && place != NSWindowOut && (window.styleMask & NSWindowStyleMaskTitled) && !window.titlebarAppearsTransparent) {
      window.titlebarAppearsTransparent = YES;
      if ([window.backgroundColor isEqual:NSColor.windowBackgroundColor]) {
         window.backgroundColor = [NSColor colorNamed:@"BackgroundViewControlbar"];
      }
   }
   ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))origOrderWindow)(window, sel, place, other);
}

// Legacy scroller tracks are transparent and show the clip view background. Some Logic scroll
// views, for example in the Piano Roll, use the system controlBackgroundColor, which is white.
static NSColor *hookClipBackground(NSClipView *view, SEL sel) {
   NSColor *color = ((NSColor *(*)(id, SEL))origClipBackground)(view, sel);

   if (shouldSkip() || isPluginWindow(view.window)) {
      return color;
   }
   return [color isEqual:NSColor.controlBackgroundColor] ? scaledControlBackground : color;
}

// On macOS 26, the toolbar groups sit on glass platters, which are near white in Aqua. On a
// gray title bar they stand out, so the glass becomes partly transparent. A glass container
// above the platters renders all of them, so the opacity goes on that container. The buttons are
// not inside it. A tint, or an opacity on a platter, does not change the lightness.
static void hookPlatterLayout(NSView *platter, SEL sel) {
   NSView *glass = platter.superview.superview;

   if (isRealtimeThread() || isPluginWindow(platter.window)) {
      ((void (*)(id, SEL))origPlatterLayout)(platter, sel);
      return;
   }
   if ([glass isKindOfClass:objc_getClass("NSGlassContainerView")] && glass.alphaValue != PLATTER_ALPHA) {
      glass.alphaValue = PLATTER_ALPHA;
   }
   ((void (*)(id, SEL))origPlatterLayout)(platter, sel);
}

static IMP swapClassMethod(Class cls, SEL sel, IMP hook) {
   return method_setImplementation(class_getClassMethod(cls, sel), hook);
}

static void renderTest(void) {
   int delay = getenv("LP_DELAY") ? atoi(getenv("LP_DELAY")) : 30;

   // LP_PLAY starts playback halfway, so the audio threads run while the theme is active.
   if (getenv("LP_PLAY")) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay * NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
         NSWindow *target = NSApp.keyWindow ?: NSApp.mainWindow;
         NSEvent *down = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:target.windowNumber context:nil characters:@" " charactersIgnoringModifiers:@" " isARepeat:NO keyCode:49];
         NSEvent *up = [NSEvent keyEventWithType:NSEventTypeKeyUp location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:target.windowNumber context:nil characters:@" " charactersIgnoringModifiers:@" " isARepeat:NO keyCode:49];

         [NSApp sendEvent:down];
         [NSApp sendEvent:up];
      });
   }

   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
      int index = 0;
      NSMutableString *log = [NSMutableString stringWithFormat:@"check=ok\napp=%@ effective=%@ recolored=%d\nrealtimeSkips=%ld\n", NSApp.appearance.name, NSApp.effectiveAppearance.name, recoloredImages, atomic_load(&realtimeSkips)];

      for (NSWindow *w in NSApp.windows) {
         NSView *root = w.contentView.superview ?: w.contentView;
         NSBitmapImageRep *rep = w.isVisible ? [root bitmapImageRepForCachingDisplayInRect:root.bounds] : nil;

         if (rep) {
            [root cacheDisplayInRect:root.bounds toBitmapImageRep:rep];
            [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[outDir stringByAppendingFormat:@"/window-%d.png", index] atomically:YES];
            [log appendFormat:@"%@ '%@' effective=%@ plugin=%@\n", w.class, w.title, w.effectiveAppearance.name, isPluginWindow(w) ? @"yes" : @"no"];
            index += 1;
         }
      }
      [log writeToFile:[outDir stringByAppendingPathComponent:@"theme.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
      _exit(0); // Quits with no save prompt, because the test project is a scratch copy.
   });
}

/**
 * Reads a number from the environment, or else from the launcher preferences, and clamps it.
 *
 * @param envName const char * - the environment variable, which wins over the preferences
 * @param key NSString * - the key in SETTINGS_DOMAIN
 * @param fallback double - the value if neither source has one
 * @param low double - the lowest allowed value
 * @param high double - the highest allowed value
 * @return double - the value
 */
static double readSetting(const char *envName, NSString *key, double fallback, double low, double high) {
   id stored = [[[NSUserDefaults alloc] initWithSuiteName:SETTINGS_DOMAIN] objectForKey:key];
   double value = fallback;

   if (getenv(envName)) {
      value = atof(getenv(envName));
   } else if ([stored respondsToSelector:@selector(doubleValue)]) {
      value = [stored doubleValue];
   }
   return fmin(high, fmax(low, value));
}

/**
 * Checks that every class and method the theme relies on is there. A Logic Pro or macOS update
 * can remove one; then the theme installs nothing and Logic Pro runs in its stock look, rather
 * than half themed or unsafe. The result goes to the preferences, so the app can say why.
 *
 * @return NSString * - nil when all is there, or the first missing part
 */
static NSString *missingPart(void) {
   // Only classes the theme hooks at launch. Plug-in window classes are not required here: a
   // missing one must not turn the whole theme off (2026-11-14), and plug-in code is protected
   // by its code ranges as well.
   NSArray<NSString *> *classes = @[ @"CUINamedColor", @"MAAssetManager", @"UINibDecoder", @"CTooltipView" ];
   NSArray<NSArray<NSString *> *> *methods = @[
      @[ @"CUINamedColor", @"cgColor" ],
      @[ @"MAAssetManager", @"CompositeImageFromDescription:withContext:" ],
      @[ @"MAAssetManager", @"UICatalogFromDescription:withContext:" ],
      @[ @"UINibDecoder", @"decodeObjectForKey:" ],
      @[ @"CTooltipView", @"labelAttributes" ],
      @[ @"CTooltipView", @"valueAttributes" ],
      @[ @"CTooltipView", @"rightAlignedValueAttributes" ],
      @[ @"NSWindow", @"orderWindow:relativeTo:" ],
      @[ @"NSImage", @"drawInRect:fromRect:operation:fraction:respectFlipped:hints:" ],
      @[ @"NSImageRep", @"drawInRect:fromRect:operation:fraction:respectFlipped:hints:" ],
      @[ @"NSImage", @"bestRepresentationForRect:context:hints:" ],
      @[ @"NSTextField", @"setBackgroundColor:" ],
      @[ @"NSAppearance", @"initWithCoder:" ],
      @[ @"NSTableHeaderView", @"drawRect:" ],
      @[ @"NSButtonCell", @"drawImage:withFrame:inView:" ],
      @[ @"CLgNotesTextView", @"adjustDarkText" ],
      @[ @"_TtC5Logic17ToolbarButtonCell", @"drawImage:withFrame:inView:" ],
      @[ @"NSTextView", @"setInsertionPointColor:" ],
      @[ @"NSTextView", @"setTypingAttributes:" ],
      @[ @"NSApplication", @"setAppearance:" ],
      @[ @"NSClipView", @"backgroundColor" ],
      @[ @"NSView", @"viewDidMoveToWindow" ],
      @[ @"NSView", @"setAppearance:" ],
   ];
   NSArray<NSString *> *colorMethods = @[ @"colorWithCalibratedWhite:alpha:", @"colorWithDeviceWhite:alpha:", @"colorWithWhite:alpha:",
      @"colorWithGenericGamma22White:alpha:", @"colorWithCalibratedRed:green:blue:alpha:", @"colorWithDeviceRed:green:blue:alpha:",
      @"colorWithRed:green:blue:alpha:", @"colorWithSRGBRed:green:blue:alpha:", @"blackColor", @"whiteColor", @"darkGrayColor",
      @"lightGrayColor", @"grayColor", @"secondaryLabelColor", @"tertiaryLabelColor" ];

   for (NSString *name in classes) {
      if (!objc_getClass(name.UTF8String)) {
         return name;
      }
   }
   for (NSArray<NSString *> *pair in methods) {
      if (!class_getInstanceMethod(objc_getClass(pair[0].UTF8String), NSSelectorFromString(pair[1]))) {
         return [NSString stringWithFormat:@"%@ %@", pair[0], pair[1]];
      }
   }
   for (NSString *name in colorMethods) {
      if (!class_getClassMethod([NSColor class], NSSelectorFromString(name))) {
         return [@"NSColor " stringByAppendingString:name];
      }
   }
   if (!class_getClassMethod([NSAppearance class], @selector(appearanceNamed:))) {
      return @"NSAppearance appearanceNamed:";
   }
   if (!class_getInstanceVariable(objc_getClass("_TtC5Logic17ToolbarButtonCell"), "onColor")) {
      return @"ToolbarButtonCell onColor";
   }
   if (![NSAppearance respondsToSelector:@selector(currentDrawingAppearance)]) {
      return @"NSAppearance currentDrawingAppearance";
   }
   return nil;
}

static void recordCheck(NSString *result) {
   NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:SETTINGS_DOMAIN];

   [defaults setObject:result forKey:@"themeCheck"];
   [defaults setObject:NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"" forKey:@"themeCheckBuild"];
}

/**
 * Reads the settings of each area from the preferences. A missing or bad value means the area
 * follows the overall values.
 */
static void readAreaSettings(void) {
   NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:SETTINGS_DOMAIN];

   for (int i = 0; i < AREA_COUNT; i++) {
      NSString *prefix = [NSString stringWithFormat:@"area.%@.", AREA_KEYS[i]];
      id mode = [defaults objectForKey:[prefix stringByAppendingString:@"mode"]];
      id lightest = [defaults objectForKey:[prefix stringByAppendingString:@"surfaceMax"]];
      id gamma = [defaults objectForKey:[prefix stringByAppendingString:@"gamma"]];

      areaSettings[i].mode = [mode respondsToSelector:@selector(intValue)] ? [mode intValue] : AREA_MODE_OVERALL;
      if (areaSettings[i].mode < AREA_MODE_OVERALL || areaSettings[i].mode > AREA_MODE_ORIGINAL) {
         areaSettings[i].mode = AREA_MODE_OVERALL;
      }
      areaSettings[i].surfaceMax = fmin(1, fmax(SURFACE_MAX_MIN, [lightest respondsToSelector:@selector(doubleValue)] ? [lightest doubleValue] : surfaceMax));
      if (i == AREA_PLUGINS) {
         areaSettings[i].mode = AREA_MODE_ORIGINAL;
      }
      areaSettings[i].gamma = fmin(GAMMA_MAX, fmax(GAMMA_MIN, [gamma respondsToSelector:@selector(doubleValue)] ? [gamma doubleValue] : grayGamma));
   }
}

/**
 * Adds the colors in the JSON output of assetutil and their appearances to a shared table.
 *
 * @param output NSData * - the output of assetutil --info
 * @param appearances NSMutableDictionary * - color name to the set of its appearances
 */
static void addColorItems(NSData *output, NSMutableDictionary<NSString *, NSMutableSet *> *appearances) {
   NSArray *items = output ? [NSJSONSerialization JSONObjectWithData:output options:0 error:nil] : nil;

   if (![items isKindOfClass:NSArray.class]) {
      return;
   }
   @synchronized (appearances) {
      for (NSDictionary *item in items) {
         NSString *name;

         if (![item isKindOfClass:NSDictionary.class] || ![item[@"AssetType"] isEqual:@"Color"]) {
            continue;
         }
         name = item[@"Name"];
         if (![name isKindOfClass:NSString.class]) {
            continue;
         }
         if (!appearances[name]) {
            appearances[name] = [NSMutableSet set];
         }
         [appearances[name] addObject:item[@"Appearance"] ?: @"any"];
      }
   }
}

/**
 * Adds the color names of one asset catalog and their appearances to a shared table.
 *
 * @param path NSString * - the .car file
 * @param appearances NSMutableDictionary * - color name to the set of its appearances
 */
static void addCatalogColors(NSString *path, NSMutableDictionary<NSString *, NSMutableSet *> *appearances) {
   NSTask *task = [[NSTask alloc] init];
   NSPipe *pipe = [NSPipe pipe];
   NSData *output;

   task.executableURL = [NSURL fileURLWithPath:ASSETUTIL_PATH];
   task.arguments = @[ @"--info", path ];
   task.standardOutput = pipe;
   task.standardError = [NSFileHandle fileHandleWithNullDevice];
   if (![task launchAndReturnError:nil]) {
      return;
   }
   output = [pipe.fileHandleForReading readDataToEndOfFile];
   [task waitUntilExit];
   addColorItems(output, appearances);
}

/**
 * Lists the Logic Pro catalog colors with one appearance. Only these colors are mapped,
 * because a color with a light appearance already has a light value. The list comes from
 * the cache, or else from assetutil, which takes about one second for all catalogs.
 *
 * @return NSSet * - the color names
 */
static NSSet<NSString *> *listSingleAppearanceNames(void) {
   NSString *contents = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents"];
   NSString *build = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"unknown";
   NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:COLOR_CACHE_DIR];
   NSString *cache = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"logic-colors-%@.txt", build]];
   NSString *saved = [NSString stringWithContentsOfFile:cache encoding:NSUTF8StringEncoding error:nil];
   NSString *frameworks = [contents stringByAppendingPathComponent:@"Frameworks"];
   NSMutableArray<NSString *> *catalogs = [NSMutableArray arrayWithObject:[contents stringByAppendingPathComponent:@"Resources/Assets.car"]];
   NSMutableDictionary<NSString *, NSMutableSet *> *appearances = [NSMutableDictionary dictionary];
   NSMutableArray<NSString *> *names = [NSMutableArray array];

   if (saved.length > 0) {
      return [NSSet setWithArray:[saved componentsSeparatedByString:@"\n"]];
   }
   for (NSString *framework in [NSFileManager.defaultManager contentsOfDirectoryAtPath:frameworks error:nil]) {
      NSString *resources = [frameworks stringByAppendingPathComponent:[framework stringByAppendingPathComponent:@"Versions/A/Resources"]];

      for (NSString *file in [NSFileManager.defaultManager contentsOfDirectoryAtPath:resources error:nil]) {
         if ([file.pathExtension isEqual:@"car"]) {
            [catalogs addObject:[resources stringByAppendingPathComponent:file]];
         }
      }
   }
   dispatch_apply(catalogs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
      addCatalogColors(catalogs[i], appearances);
   });
   for (NSString *name in appearances) {
      if (appearances[name].count == 1) {
         [names addObject:name];
      }
   }
   if (names.count > 0) {
      [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
      [[names componentsJoinedByString:@"\n"] writeToFile:cache atomically:YES encoding:NSUTF8StringEncoding error:nil];
   }
   return [NSSet setWithArray:names];
}

__attribute__((constructor)) static void start(void) {
   Class color = [NSColor class];
   Class manager, tooltip;

   // The hooks are only for Logic Pro. This also lets the tests include this file.
   if (![NSBundle.mainBundle.bundleIdentifier isEqual:LOGIC_BUNDLE_ID]) {
      return;
   }
   NSString *missing = missingPart();

   if (missing) {
      recordCheck([@"off: " stringByAppendingString:missing]);
      if (getenv("LP_OUT")) {
         [[@"check=off " stringByAppendingString:missing] writeToFile:[[NSString stringWithUTF8String:getenv("LP_OUT")] stringByAppendingPathComponent:@"theme.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
      }
      return;
   }
   recordCheck(@"ok");
   grayGamma = readSetting("LP_GAMMA", @"gamma", grayGamma, GAMMA_MIN, GAMMA_MAX);
   surfaceMax = readSetting("LP_SURFACE_MAX", @"surfaceMax", surfaceMax, SURFACE_MAX_MIN, 1);
   readAreaSettings();
   srgbSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
   singleAppearanceNames = listSingleAppearanceNames();
   trueAqua = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
   trueDarkAqua = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
   mappedAqua = [[NSAppearance alloc] initWithAppearanceNamed:NSAppearanceNameAqua bundle:nil];
   _dyld_register_func_for_add_image(addImage);
   // These symbols bound the three arrange view region functions, which are adjacent in Logic.
   regionDrawStart = (uintptr_t)dlsym(RTLD_DEFAULT, "_ZNK9CRegionUI31drawRegionInArrangeViewWithFlexEv");
   regionDrawEnd = (uintptr_t)dlsym(RTLD_DEFAULT, "_ZNK9CRegionUI15drawRegionFrameEv");
   panKnobDraw = functionRange("_ZN19HOTSPOTauknob127Pan5PrintER6U_VARS", "_ZNK19HOTSPOTauknob127Pan7HelpTagER6U_VARS");
   arrangeKnobDraw = functionRange("_ZN26HOTSPOTauknob127PanArrange5PrintER6U_VARS", "_ZNK26HOTSPOTauknob127PanArrange11QuickHelpIDER6U_VARS");
   trackHeaderDraw = functionRange("_Z13DoTrackHeaderR6U_VARS19TPosOneBasedTrackNrxP6CTrackS3_PK16TTrackHeaderDataP5CMSeqPKS2_SA_i", "_Z17DoAllTrackHeadersR6U_VARSP7FENSTERPv");
   textDraw = functionRange("_ZN2GC8drawTextEddPKtmd", "_ZN2GC8drawTextEddPK10__CFStringd");
   rulerMarkerDraw = functionRange("_Z12PrintMarkersR6U_VARSP5CSongP7FENSTERxx19TSignedAbsPureClockb", "_Z18ColoredMarkerAchseP5CSongP7FENSTERxxb");
   threePartDraw = functionRange("MADrawingThreePartImage", "MADrawingTwoPartVerticalImage");
   fillColorOf = dlsym(RTLD_DEFAULT, "CGContextGetFillColorAsColor");

   origAppearanceNamed = swapClassMethod([NSAppearance class], @selector(appearanceNamed:), (IMP)hookAppearanceNamed);
   origAppSetAppearance = method_setImplementation(class_getInstanceMethod([NSApplication class], @selector(setAppearance:)), (IMP)hookAppSetAppearance);
   origCGColor = method_setImplementation(class_getInstanceMethod(NSClassFromString(@"CUINamedColor"), @selector(cgColor)), (IMP)hookCGColor);
   origCalWhite = swapClassMethod(color, @selector(colorWithCalibratedWhite:alpha:), (IMP)hookCalWhite);
   origDevWhite = swapClassMethod(color, @selector(colorWithDeviceWhite:alpha:), (IMP)hookDevWhite);
   origWhite = swapClassMethod(color, @selector(colorWithWhite:alpha:), (IMP)hookWhite);
   origGenWhite = swapClassMethod(color, @selector(colorWithGenericGamma22White:alpha:), (IMP)hookGenWhite);
   origCalRGB = swapClassMethod(color, @selector(colorWithCalibratedRed:green:blue:alpha:), (IMP)hookCalRGB);
   origDevRGB = swapClassMethod(color, @selector(colorWithDeviceRed:green:blue:alpha:), (IMP)hookDevRGB);
   origRGB = swapClassMethod(color, @selector(colorWithRed:green:blue:alpha:), (IMP)hookRGB);
   origSRGB = swapClassMethod(color, @selector(colorWithSRGBRed:green:blue:alpha:), (IMP)hookSRGB);
   origBlack = swapClassMethod(color, @selector(blackColor), (IMP)hookBlack);
   origWhiteColor = swapClassMethod(color, @selector(whiteColor), (IMP)hookWhiteColor);
   origDarkGray = swapClassMethod(color, @selector(darkGrayColor), (IMP)hookDarkGray);
   origLightGray = swapClassMethod(color, @selector(lightGrayColor), (IMP)hookLightGray);
   origGray = swapClassMethod(color, @selector(grayColor), (IMP)hookGray);
   origSecondaryLabel = swapClassMethod(color, @selector(secondaryLabelColor), (IMP)hookSecondaryLabel);
   origTertiaryLabel = swapClassMethod(color, @selector(tertiaryLabelColor), (IMP)hookTertiaryLabel);
   manager = objc_getClass("MAAssetManager");
   origCompositeImage = method_setImplementation(class_getInstanceMethod(manager, NSSelectorFromString(@"CompositeImageFromDescription:withContext:")), (IMP)hookCompositeImage);
   origCatalogImage = method_setImplementation(class_getInstanceMethod(manager, NSSelectorFromString(@"UICatalogFromDescription:withContext:")), (IMP)hookCatalogImage);
   origImageDraw = method_setImplementation(class_getInstanceMethod([NSImage class], @selector(drawInRect:fromRect:operation:fraction:respectFlipped:hints:)), (IMP)hookImageDraw);
   origRepDraw = method_setImplementation(class_getInstanceMethod([NSImageRep class], @selector(drawInRect:fromRect:operation:fraction:respectFlipped:hints:)), (IMP)hookRepDraw);
   origBestRep = method_setImplementation(class_getInstanceMethod([NSImage class], @selector(bestRepresentationForRect:context:hints:)), (IMP)hookBestRep);
   origAdjustDarkText = method_setImplementation(class_getInstanceMethod(objc_getClass("CLgNotesTextView"), NSSelectorFromString(@"adjustDarkText")), (IMP)hookAdjustDarkText);
   notesTextView = objc_getClass("CLgNotesTextView");
   origSetCaretColor = method_setImplementation(class_getInstanceMethod([NSTextView class], @selector(setInsertionPointColor:)), (IMP)hookSetCaretColor);
   origSetTypingAttributes = method_setImplementation(class_getInstanceMethod([NSTextView class], @selector(setTypingAttributes:)), (IMP)hookSetTypingAttributes);
   origFieldBackground = method_setImplementation(class_getInstanceMethod([NSTextField class], @selector(setBackgroundColor:)), (IMP)hookFieldBackground);
   origNibDecode = method_setImplementation(class_getInstanceMethod(objc_getClass("UINibDecoder"), @selector(decodeObjectForKey:)), (IMP)hookNibDecode);
   origAppearanceDecode = method_setImplementation(class_getInstanceMethod([NSAppearance class], @selector(initWithCoder:)), (IMP)hookAppearanceDecode);
   origHeaderDraw = method_setImplementation(class_getInstanceMethod([NSTableHeaderView class], @selector(drawRect:)), (IMP)hookHeaderDraw);
   toolbarOnColor = class_getInstanceVariable(objc_getClass("_TtC5Logic17ToolbarButtonCell"), "onColor");
   origToolbarImage = method_setImplementation(class_getInstanceMethod(objc_getClass("_TtC5Logic17ToolbarButtonCell"), @selector(drawImage:withFrame:inView:)), (IMP)hookToolbarImage);
   origButtonImage = method_setImplementation(class_getInstanceMethod([NSButtonCell class], @selector(drawImage:withFrame:inView:)), (IMP)hookButtonImage);
   origViewMoved = method_setImplementation(class_getInstanceMethod([NSView class], @selector(viewDidMoveToWindow)), (IMP)hookViewMoved);
   origViewSetAppearance = method_setImplementation(class_getInstanceMethod([NSView class], @selector(setAppearance:)), (IMP)hookViewSetAppearance);
   // Always installed: it keeps every plug-in window in the stock dark look.
   origOrderWindow = method_setImplementation(class_getInstanceMethod([NSWindow class], @selector(orderWindow:relativeTo:)), (IMP)hookOrderWindow);
   if (surfaceMax < 1) {
      scaledControlBackground = [NSColor colorWithSRGBRed:surfaceMax green:surfaceMax blue:surfaceMax alpha:1];
      origClipBackground = method_setImplementation(class_getInstanceMethod([NSClipView class], @selector(backgroundColor)), (IMP)hookClipBackground);
      if (objc_getClass("NSToolbarPlatterView")) {
         origPlatterLayout = method_setImplementation(class_getInstanceMethod(objc_getClass("NSToolbarPlatterView"), @selector(layout)), (IMP)hookPlatterLayout);
      }
   }
   tooltip = objc_getClass("CTooltipView");
   origTooltipLabel = method_setImplementation(class_getInstanceMethod(tooltip, NSSelectorFromString(@"labelAttributes")), (IMP)hookTooltipLabel);
   origTooltipValue = method_setImplementation(class_getInstanceMethod(tooltip, NSSelectorFromString(@"valueAttributes")), (IMP)hookTooltipValue);
   origTooltipRightValue = method_setImplementation(class_getInstanceMethod(tooltip, NSSelectorFromString(@"rightAlignedValueAttributes")), (IMP)hookTooltipRightValue);
   if (getenv("LP_OUT")) {
      outDir = [NSString stringWithUTF8String:getenv("LP_OUT")];
      renderTest();
   }
}
