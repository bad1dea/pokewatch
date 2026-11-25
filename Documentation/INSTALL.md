# Installing on Apple Watch

## TestFlight (main route)

PokéWatch is an iPhone app (`PokeWatchPhone`) carrying the watch app in `Watch/`. TestFlight installs the
iPhone app; the watch app installs from it (automatically, or from the Watch app's Available Apps). The watch
app runs on its own without the iPhone.

One-time setup:

1. Repository secrets (shared with the other apps): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`,
   `DEVELOPMENT_TEAM`, `DIST_CERT_P12_BASE64`, `DIST_CERT_PASSWORD`.
2. Run **Actions › Apple setup**. It registers `ng.khuo.pokewatch` (the iOS watch-only container that
   App Store Connect requires), `ng.khuo.pokewatch.watchkitapp` and `ng.khuo.pokewatch.watchkitapp.widgets`
   (both with HealthKit), and makes their App Store profiles. Every run remakes the profiles: store the
   `pokewatch-profiles` artifact's files base64-encoded as `DIST_PROFILE_BASE64`, `DIST_PROFILE_WATCH_BASE64`
   and `DIST_PROFILE_WIDGETS_BASE64`.
3. App Store Connect › Apps › **New App**: platform iOS, bundle ID `ng.khuo.pokewatch`, any free name
   and SKU. (The API can't create app records.) Run Apple setup again to create the internal
   TestFlight group.

Each release: **Actions › TestFlight › Run workflow**. It builds with Xcode 27 on the `xcode-27`
runner, uploads, waits for processing and adds the build to the internal group. On the iPhone:
TestFlight › PokéWatch › Install, and the app appears on the watch.

## What's left for you on Apple's side

Nothing is required for internal TestFlight: the bundle ids, HealthKit capability, profiles and the app
record already exist, and the iPhone app reuses the record's bundle id (`ng.khuo.pokewatch`).

- **TestFlight**: run Actions › TestFlight. Install PokéWatch on the iPhone from TestFlight; the watch app
  installs from it (or from the Watch app › Available Apps).
- **Optional, App Store Connect › App Information**: subtitle, category (Lifestyle), and the Watch and
  iPhone screenshots if you want them in TestFlight's listing.
- **Not recommended: App Store release.** The game sprites and Pokémon names are Nintendo's; App Review
  rejects apps using third-party IP without permission (guideline 5.2). Keep it to internal TestFlight.

## Xcode (development)

1. `Scripts/generate.sh`, open `PokeWatch.xcodeproj`.
2. Select your team for both targets (Signing & Capabilities). HealthKit is already in the entitlements.
3. Watch: Settings › Privacy & Security › Developer Mode on; paired iPhone trusted by the Mac.
4. Choose the watch as destination and run. Or from Terminal:
   `DEVELOPMENT_TEAM=XXXXXXXXXX Scripts/install-device.sh`.

Deploying to a watch on watchOS 27 needs an Xcode with watchOS 27 device support (Xcode 27).

## After installing

- Settings › General › Return to Clock › PokéWatch › **Return to App** (see ALWAYS_ON.md).
- Long-press the watch face › Edit › Complications › **PokéWatch**: pick a slot on Modular Ultra or
  another face, then pick the Pokémon.

## Physical-device checklist

Simulator testing doesn't prove any of these. Check them on the watch:

- [ ] Launches standalone with the iPhone in airplane mode.
- [ ] Health prompt appears once; denying it leaves every face working with "--" activity.
- [ ] Steps, active energy, exercise minutes and rings match the Activity app (within a refresh).
- [ ] Heart rate shows only after enabling it, and no continuous sampling shows up in Health.
- [ ] Wrist down: face dims, Pokémon asleep, no seconds, no particles; time stays correct over 10+ min.
- [ ] Wrist up: wake-up animation plays once, then normal animation resumes.
- [ ] Return to Clock › Return to App keeps PokéWatch on wrist raise.
- [ ] Each of the six faces: nothing hidden under the system time; text legible in sunlight and dimmed.
- [ ] Tap, double-tap, long-press, swipe and Crown all work; none interferes with system gestures.
- [ ] Haptics fire only with Haptics on.
- [ ] Low Power Mode: animation slows, particles off.
- [ ] Reduce Motion (system and app toggle): companion stops moving, blinks continue.
- [ ] Battery: Pokéball level matches Control Center; charging shows the charging mood.
- [ ] Battery ≤ 20 %: tired mood.
- [ ] All four complication families on Modular Ultra, in Night Mode (red tint) and on a tinted face.
- [ ] Complication tap opens PokéWatch.
- [ ] Battery drain over an hour of Return to App use is comparable to the system face (Settings › Battery).
