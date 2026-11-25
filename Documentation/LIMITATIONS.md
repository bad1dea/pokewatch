# Known platform limitations

- **Not a real watch face.** Apple doesn't allow third-party watch faces. PokéWatch is an app
  shown on wrist raise via Return to Clock, plus complications on Apple's faces. See ALWAYS_ON.md.
- **System time overlay.** watchOS draws its own time in the top-right corner of every app. Layouts
  leave that corner clear.
- **Always-On cadence** is controlled by the system (about once a minute, sometimes a blurred
  snapshot). The app can't animate there.
- **Complications** don't animate and refresh on a system budget (here: 15-minute entries for 2 hours,
  plus a reload request when steps move). Battery in a complication only shows when WatchKit reports a
  level to the extension; it's never projected forward.
- **HealthKit** never reveals whether read access was denied. Denied and no data look the same, and
  the face shows "--". Ring goals need the Activity summary type.
- **Battery** on the simulator is unavailable; screenshots use `--demo` data.
- **watchOS 27 SDK.** Local builds use Xcode 26.6 (watchOS 26.5 SDK) on an Intel Mac, where Xcode 27
  doesn't run and the Overtime SDK shim doesn't support watchOS. The deployment target is watchOS 26.0,
  so it runs on watchOS 27. TestFlight builds come from the `xcode-27` GitHub runner and link against
  the watchOS 27 SDK.
- **Simulator ≠ device.** Simulator runs prove layout and logic, not battery life, Always-On
  behaviour or real HealthKit data.
