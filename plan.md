# TapDim — Implementation Plan

## Overview

TapDim is a macOS menu bar utility that toggles screen brightness between the user's current level and a configurable dim target via a global keyboard shortcut (v0). Built with Swift, SwiftUI, and AppKit for macOS 14.6+ on Apple Silicon. Future versions may add physical double-tap detection via IOKit HID accelerometer access.

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI (settings window, about window) + AppKit (menu bar, app lifecycle)
- **Trigger (v0):** Global keyboard shortcut via `sindresorhus/KeyboardShortcuts` SPM package (user-configurable)
- **Brightness:** `DisplayServicesSetBrightness` via dlopen from DisplayServices.framework (private API, confirmed working on Apple Silicon). Fallback: `CoreDisplay_Display_SetUserBrightness`. Last resort: `IODisplaySetFloatParameter`
- **Login item:** ServiceManagement `SMAppService` (macOS 13+)
- **Build:** Swift Package Manager
- **Persistence:** UserDefaults for settings

## Research Findings (pre-build)

1. **CoreMotion does NOT work on macOS** — `isAccelerometerAvailable` returns `false` on all Macs including Apple Silicon. Dead end.
2. **IOKit HID accelerometer works but requires root** — via `AppleSPUHIDDevice`, vendor usage page `0xFF00`, usage `0x03`. Requires sudo or LaunchDaemon. Too complex for v0, deferred to v1.
3. **Brightness API cascade:** `DisplayServicesSetBrightness` (preferred) → `CoreDisplay_Display_SetUserBrightness` (fallback) → `IODisplaySetFloatParameter` (last resort). All via dlopen. Must call `DisplayServicesBrightnessChanged` after setting to update system UI.
4. **KeyboardShortcuts SPM package** is the standard for global hotkeys on macOS 14+. Sandbox-safe, App Store compatible, user-configurable with built-in recorder UI.

## Features

| # | Feature | Approach | Complexity |
|---|---------|----------|------------|
| 1 | App shell (menu bar, no dock icon) | AppKit `NSApplication` + `LSUIElement`, `NSStatusItem` for menu bar | Low |
| 2 | Menu bar dropdown | `NSMenu` with status line, enable/disable toggle, Settings, About, Quit | Low |
| 3 | Brightness control | dlopen DisplayServices.framework → `DisplayServicesSetBrightness` + `DisplayServicesBrightnessChanged` | Medium |
| 4 | Toggle state logic | `savedBrightness` / `targetBrightness`, simple if/else | Low |
| 5 | Keyboard shortcut trigger | `sindresorhus/KeyboardShortcuts` SPM, user-configurable, default unset | Low |
| 6 | Settings window | SwiftUI form: target brightness slider (0-50%), shortcut recorder, launch at login toggle, enable toggle | Low |
| 7 | About window | SwiftUI modal: icon, version, one-liner, "Made by Santiago Alonso", website link | Low |
| 8 | Launch at login | `SMAppService.mainApp.register()` / `.unregister()` | Low |

## File Structure

```
TapDim/
  Package.swift
  Sources/
    TapDim/
      App/
        TapDimApp.swift              # @main, NSApplication setup
        AppDelegate.swift             # Menu bar, status item, window management
      Core/
        BrightnessController.swift    # dlopen DisplayServices, get/set brightness
        ToggleManager.swift           # State logic: saved vs target brightness
      UI/
        SettingsView.swift            # SwiftUI settings form
        AboutView.swift               # SwiftUI about window
      Utilities/
        Settings.swift                # @AppStorage / UserDefaults wrapper
        Constants.swift               # Default values
  Tests/
    TapDimTests/
      ToggleManagerTests.swift
      BrightnessControllerTests.swift
```

## Implementation Order

1. **Package.swift + app shell** — SPM project, menu bar icon, dropdown menu, `LSUIElement` (features 1 + 2)
2. **Brightness control** — dlopen DisplayServices, get/set brightness functions (feature 3)
3. **Toggle state logic** — wire brightness toggle, test manually from menu item (feature 4)
4. **Keyboard shortcut trigger** — add KeyboardShortcuts dependency, register global hotkey (feature 5)
5. **Settings window** — SwiftUI form with slider + shortcut recorder + toggles (feature 6)
6. **About window** — modal with credits (feature 7)
7. **Launch at login** — SMAppService toggle (feature 8)

## Design Context

- **Screen type:** Menu bar utility — no main window, just dropdown menu + settings/about panels
- **Theme:** System (follows macOS light/dark mode automatically)
- **Aesthetic:** Clean, native macOS feel. Standard system controls. No custom chrome.
- **First 60 seconds:** User launches app → icon appears in menu bar → sets keyboard shortcut in Settings → presses shortcut → screen dims → presses again → brightness restores.

## Deferred to v1

- Physical double-tap detection via IOKit HID accelerometer (requires root/LaunchDaemon architecture)
- Tap sensitivity, tap window, and cooldown sliders (only relevant with accelerometer)
- Typing false-positive filter (only relevant with accelerometer)
- Lid-closed auto-disable

---

## Run Contract

```yaml
run_contract:
  max_iterations: 30
  completion_promise: "V0_COMPLETE"
  on_stuck: defer_and_continue
  on_ambiguity: choose_simpler_option
  on_regression: revert_to_last_clean_commit
  human_intervention: never
  visual_qa_max_passes: 1
  visual_qa_agentation: skip
  phase_skip:
    qa_console: true        # No browser — macOS native app
    visual_qa: false         # Will screenshot and check window layout
    security: false
  complexity_overrides:
    trigger: "KeyboardShortcuts SPM package — user-configurable global hotkey"
    brightness_control: "dlopen DisplayServices.framework → DisplayServicesSetBrightness cascade"
    settings_persistence: "UserDefaults"
    login_item: "SMAppService.mainApp"
    ui_framework: "SwiftUI for windows, AppKit for menu bar"
```
