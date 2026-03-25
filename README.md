<p align="center">
<img src="https://img.icons8.com/emoji/128/sun-emoji.png" width="128" height="128" alt="TapDim icon">
</p>

<h1 align="center">TapDim</h1>

<p align="center">
Double-tap your MacBook to dim. Double-tap to restore.<br>
A lightweight menu bar utility for Apple Silicon MacBooks.
</p>

<p align="center">
v1.0 · macOS 14.6+ · Apple Silicon
</p>

---

## How It Works

TapDim uses the built-in accelerometer on Apple Silicon MacBooks to detect physical taps on the chassis. Tap to dim your screen to a configurable level. Tap again to restore.

No permissions required. No dock icon. Just a sun in your menu bar.

## Features

- **Physical tap detection** — 1, 2, or 3 taps (configurable)
- **Keyboard shortcut** — set any global hotkey as a backup trigger
- **Configurable brightness** — dim to 0-50% (default 10%)
- **Tunable sensitivity** — adjust g-force threshold, tap window, and cooldown
- **Launch at login** — optional auto-start
- **Zero permissions** — no accessibility, no input monitoring, no root

## Install

Download the latest DMG from [Releases](../../releases), open it, and drag TapDim to Applications.

## Settings

| Setting | Default | Range |
|---|---|---|
| Target brightness | 10% | 0–50% |
| Taps to trigger | 2 | 1–3 |
| Sensitivity | 0.10g | 0.02–0.50g |
| Tap window | 400ms | 200–800ms |
| Cooldown | 0.3s | 0.3–3.0s |

## Compatibility

- macOS 14.6+ (Sonoma)
- Apple Silicon only (M1, M2, M3, M4)
- MacBooks only (no desktop Macs — no accelerometer)

## Build from Source

```bash
swift build -c release
.build/release/TapDim
```

## How It Works (Technical)

TapDim accesses the undocumented MEMS accelerometer (Bosch BMI286) on Apple Silicon MacBooks via IOKit HID (`AppleSPUHIDDevice`, vendor usage page `0xFF00`). Screen brightness is controlled through the private `DisplayServices.framework` API.

---

Made by [santiagoalonso.com](https://santiagoalonso.com)
