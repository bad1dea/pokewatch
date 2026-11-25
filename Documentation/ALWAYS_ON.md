# Always-On

## What the app does

| | Active (wrist raised) | Reduced luminance (wrist down) |
| --- | --- | --- |
| Timeline | `TimelineView(.animation)`, adaptive fps | `TimelineView(.everyMinute)` |
| Companion | animated by mood | static sleeping pose, eyes closed, dimmed to 42 % (or silhouette / hidden) |
| Seconds | optional | always hidden |
| Particles | yes (unless Low Power / Reduce Motion) | none |
| Colours | full palette | dim greys and muted accents, fewer lit pixels |

The switch is driven by SwiftUI's `isLuminanceReduced`. When it turns false again, `AppModel.wake()`
starts the 1.6 s wake-up animation (stretch, blink, happy hop, "Pika!"). `scenePhase` pauses the
active timeline and stops the once-a-minute battery/Health refresh loop.

`WKSupportsAlwaysOnDisplay` is set in Info.plist. The Always-On look is chosen in Settings:
Sleeping Pokémon, Silhouette or Clock only.

## What the app can't do

- It can't detect a wrist raise or drop directly. It only sees the luminance and scene-phase changes
  the system reports.
- It doesn't control screen brightness or the refresh rate. In Always-On the system decides when to
  redraw (about once a minute) and may show a blurred or snapshotted frame instead.
- It can't keep itself frontmost. There's no background audio, fake workout or extended runtime
  session; those would be misuse and drain the battery.

## Return to Clock

By default watchOS goes back to the watch face 2 minutes after the wrist drops. To keep PokéWatch on
screen:

1. On the watch: **Settings › General › Return to Clock**.
2. Scroll to **PokéWatch** and choose **Return to App**, or set the app's timeout (up to 1 hour).
   Or on iPhone: Watch app › General › Return to Clock.

Limits: the longest per-app timeout is 1 hour. Opening another app, a notification, or a restart
returns to the system face. That's watchOS policy and no public API changes it. A complication on
the real watch face (see INSTALL.md) is the always-available way back in.

## Simulator caveat

The simulator doesn't reproduce Always-On. The `--dimmed` launch switch renders the reduced-luminance
design for screenshots; real behaviour, cadence and power draw must be checked on the watch (see the
checklist in INSTALL.md).
