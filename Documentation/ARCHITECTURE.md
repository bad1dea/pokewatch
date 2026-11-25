# Architecture

```
PokeWatch/
  App/           entry point, AppModel (services + interaction state), RootView (gestures)
  Core/
    Clock/       ClockFormatter: allocation-light time strings
    Animation/   CompanionAnimator (pure pose function), MotionPolicy (frame rate), variants
    Health/      HealthQueries (read-only, shared with widgets), HealthService, ActivitySnapshot
    Battery/     BatteryMonitor (WatchKit + Low Power Mode), BatterySnapshot
    Persistence/ SettingsStore (UserDefaults), LaunchOptions (automation switches)
  Characters/    CharacterDefinition (JSON), CharacterRegistry, SpriteStyle/SpriteClip/SpriteLibrary
                 (imported animations), SpriteRasterizer (fallback pixel art), MoodEngine
  WatchFaces/    FaceStyle, FaceContext, FaceHost (timelines), six faces
  Components/    PixelFont, SpriteImage, CompanionView, ParticleField, PokeballBattery, activity views
  Settings/      CustomizeView (Crown pickers), SettingsView
  Resources/     Sprites/*.pokemon.json, Assets.xcassets, Fonts/
  Widgets/       WidgetKit extension: complications + configuration intent
  Tests/         XCTest unit tests
```

## Frame pipeline

1. `FaceHost` owns a single `TimelineView`.
   - Active: `.animation(minimumInterval: 1/fps, paused: scenePhase != .active)`.
   - Always-On: `.everyMinute`.
2. For each tick it builds a `FaceContext`: clock parts, battery, activity, mood, and a `CompanionPose`
   from `CompanionAnimator.pose(character, input)`, a pure function of time and state.
3. The face lays out text and draws the companion with `CompanionView`, which applies the pose as a
   transform to a cached `CGImage`.

There are no per-character timers or animation state machines. Blink timing, ear flicks and
particles come from deterministic hash noise over time, so a paused timeline costs nothing and
every frame is reproducible in tests.

## Sprites

Imported art: `Scripts/import_sprites.py` stores each animation as one 1× sprite sheet plus a
manifest (frame size, grid, per-frame durations). `SpriteLibrary` loads a clip on first use, cuts
frames with `CGImage.cropping` (no copies), and keeps the three most recent clips. The largest decodes
to about 3.5 MB. `CompanionView` picks the largest whole-device-pixel scale that fits the face's box
(pixels stay square and crisp) and chooses the frame from time × the mood's playback rate. Playback
rate 0 (asleep, Always-On, Reduce Motion) shows the first frame. A Pokémon missing from the chosen
generation falls back to the next newer one, then older ones. Game Boy shades are applied to the whole
sheet once and cached.

Fallback pixel art: each character is a JSON file: rows of palette keys plus a palette. `SpriteRasterizer` derives the
expressions (open, blink/closed, happy ^ ^, tired) from the eye pixels, applies the ear-flick, and
applies a tint (natural, dimmed %, four-shade Game Boy palette, flat silhouette). Each combination is
rasterized once and cached. Frames then cost a scale, rotation and offset.

## Behaviour

`MoodEngine.mood(for:inputs:)` maps time of day, battery, charging, step progress, rings and
step-idle time to one of: sleeping, drowsy, calm, happy, excited, celebrating, tired, charging.
Personality fields shift the thresholds (night owl, sleepy, step lover, naps when idle). The animator
turns the mood into motion; tap reactions and the wake-up sequence override it briefly.

## Layout

Faces lay out on absolute geometry against the measured screen shape (`ScreenShape`): any content near
the top or bottom edge is inset by the corner curve at that height, and the top-right stays clear for
the system time. `Scripts/screenshots.sh` captures every face in 12/24-hour, short/long time and date,
and Always-On; `Scripts/check_clipping.py` compares each shot with the device mask.

## Performance and battery

- One timeline per screen; paused when the scene isn't active.
- Adaptive frame rate: Calm 8, Balanced 15, Lively 30 fps; halved (min 4) 20 s after the last
  wake or tap; capped at 6 in Low Power Mode; 4 fps with no movement under Reduce Motion
  (app toggle or the system setting).
- Particles off in Low Power Mode and Reduce Motion.
- Sprite bitmaps cached; clock strings built from calendar components, not DateFormatters.
- Battery read on activation and once a minute while active. HealthKit queried at most every
  3 minutes while active, never streamed; heart rate is one most-recent sample, opt-in.
- Complication reloads are requested only when steps move by 500+, at most every 10 minutes.
- No network code at all.

SpriteKit isn't used: SwiftUI with cached bitmaps already reduces each frame to a few transforms,
and SpriteKit would add a render loop with no measurable benefit at these sprite sizes.

## iPhone app and sync

`PokeWatch/Phone/` is the iPhone target. It compiles the shared model, sprite and face code (everything
except the watch-only `AppModel`, `FaceHost`, battery and HealthKit services), so its previews are the
real faces. `SyncService` (WatchConnectivity) is shared:

- **Settings**: each side publishes `SettingsStore.syncPayload` as its application context. A payload
  carries `updatedAt`; the receiver applies it only if newer, and remote changes don't echo back.
- **Sprite packs**: the iPhone bundles the full sprite set (`Resources/Phone/`, shiny + full-rate Modern),
  builds a pack (`SpritePackArchive`: one file, JSON index plus data, paths checked against escaping the
  folder) and queues it with `transferFile`. The watch unpacks into `Application Support/SpritePacks/<kind>/`,
  adds it to `SpriteFiles.extraRoots` (searched before the bundle), and reports installed packs back.

## Complications

The widget extension shares `Characters/`, `Resources/Sprites`, `HealthQueries` and a few views with
the app. Each complication picks its Pokémon and step goal through a `WidgetConfigurationIntent`
(with `recommendations()` for the watch face editor). Steps come from its own HealthKit query
under the app's authorization; battery from WatchKit when it reports a level. There's no App Group:
the App Store Connect API can't register App Groups, and nothing here needs one.
