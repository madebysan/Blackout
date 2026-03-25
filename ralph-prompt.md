You are building a v0 prototype autonomously. You have full tool access and will work through 6 phases without any human interaction. Every decision is pre-authorized by the run contract below.

## The Plan

Read the plan file at /Users/san/Projects/TapDim/plan.md for the full implementation plan. It contains:
- Tech stack decisions
- Research findings (CoreMotion doesn't work on macOS — use keyboard shortcut trigger)
- 8 features to implement in dependency order
- File structure
- Design context
- Deferred items (accelerometer for v1)

## Project Type

swift-macos

## Run Contract

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
    qa_console: true
    visual_qa: false
    security: false
  complexity_overrides:
    trigger: "KeyboardShortcuts SPM package — user-configurable global hotkey"
    brightness_control: "dlopen DisplayServices.framework — DisplayServicesSetBrightness cascade"
    settings_persistence: "UserDefaults"
    login_item: "SMAppService.mainApp"
    ui_framework: "SwiftUI for windows, AppKit for menu bar"

---

## Your Operating Rules

### Checkpoint First
1. At the START of every iteration, read checkpoint.json from /Users/san/Projects/TapDim/
2. Pick up EXACTLY where the last iteration left off — check current_phase, current_phase_step
3. If checkpoint.json doesn't exist yet, create it with the initial schema and start Phase 1

### Granular Checkpointing
4. Update checkpoint.json after EVERY meaningful action:
   - Feature implementation started: update feature status to "in_progress"
   - Feature passes type check: update to "done", record commit hash
   - Feature fails: increment attempts, record error
   - Phase transitions: update current_phase
5. This means if the loop restarts, no work is lost or duplicated

### Git Discipline
6. Git commit after every successful feature or fix
7. Record the commit hash in checkpoint.json as last_clean_commit
8. Before starting a risky change, note the current last_clean_commit so you can revert

### 3-Strike Rule
9. If a feature or fix fails 3 attempts:
   - Add it to deferred_to_v1 in checkpoint.json with the reason
   - Revert to last_clean_commit if the failed attempts broke anything
   - Move to the next feature or phase
   - Do NOT keep trying — move on

### Regression Handling
10. After implementing each feature, verify previous features still work
11. If a regression is detected:
    - Log it in regressions_caught
    - Revert to last_clean_commit
    - Re-implement the current feature with a different approach
    - If second approach also regresses, defer the feature to v1

### Ambiguity Resolution
12. When facing a design or implementation choice, follow the run contract on_ambiguity rule
13. Default: choose the simpler option
14. Log every autonomous decision in decisions_made with reasoning
15. Check complexity_overrides in the run contract for pre-decided approaches

### Phase Tools (swift-macos)

- Scaffold: Create Package.swift + directory structure per plan
- Type Check: swift build
- Run Binary: .build/debug/TapDim
- Test: swift test

---

## Phase Execution Order

### Phase 1: Scaffold and Implement
- Create Package.swift with KeyboardShortcuts dependency
- Create directory structure per plan
- Implement features one by one from the plan (8 features, in order)
- Run swift build after each feature
- Commit after each successful feature
- Skip to Phase 2 when all features are done (or deferred)

### Phase 2: Test and Fix
- Create basic XCTest tests for ToggleManager and BrightnessController
- Run swift test
- Fix failing tests (up to 3 attempts each)
- Commit when all tests pass
- Skip to Phase 3 when done

### Phase 3: QA Console
SKIP — not applicable for swift-macos project. No browser console.

### Phase 4: Visual QA
1. Build the app (swift build)
2. Launch and screenshot main window / settings window / about window
3. Check layout, alignment, text rendering
4. Fix and rebuild if needed
- Single pass (visual_qa_max_passes: 1)

### Phase 5: Security Audit
- Check sandbox entitlements match usage
- Scan for hardcoded secrets
- Verify no unnecessary capabilities
- Fix critical issues, log medium/low for report

### Phase 6: Final Verification + Report
- Run swift build one final time
- Run swift test one final time
- Verify the app starts (smoke test)
- Generate BUILD_REPORT.md from checkpoint.json
- Commit BUILD_REPORT.md
- Output the completion promise: V0_COMPLETE

---

## Critical Reminders

- NEVER ask for human input — every decision is covered by the run contract
- NEVER skip updating checkpoint.json — it's your memory across iterations
- ALWAYS commit working state before making changes
- If something isn't working after 3 tries, DEFER and MOVE ON
- The goal is a WORKING v0, not a perfect product
- When in doubt, choose the simpler approach
- End with the completion promise V0_COMPLETE — this is how the loop knows to stop
- Working directory is /Users/san/Projects/TapDim/

## Key Technical Details from Research

### Brightness Control (dlopen pattern):

Use dlopen to load DisplayServices.framework from /System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices

Function signatures (C convention):
- DisplayServicesSetBrightness(CGDirectDisplayID, Float) -> Int32
- DisplayServicesGetBrightness(CGDirectDisplayID, UnsafeMutablePointer of Float) -> Int32
- DisplayServicesBrightnessChanged(CGDirectDisplayID, Double) -> Void

Must call DisplayServicesBrightnessChanged after setting to update system UI.

Fallback chain: DisplayServicesSetBrightness -> CoreDisplay_Display_SetUserBrightness -> IODisplaySetFloatParameter

### KeyboardShortcuts SPM:

Package dependency: .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")

Define shortcut name:
  extension KeyboardShortcuts.Name {
    static let toggleDim = Self("toggleDim")
  }

Register listener:
  KeyboardShortcuts.onKeyUp(for: .toggleDim) { toggleManager.toggle() }

Settings UI recorder:
  KeyboardShortcuts.Recorder("Toggle dim:", name: .toggleDim)

### Menu bar app pattern:
- Set LSUIElement = true (no dock icon) — use Info.plist or set NSApplication.activationPolicy to .accessory
- Use NSStatusItem for menu bar icon
- SF Symbol for icon: "sun.min" or "light.min" related
- AppDelegate pattern: NSApplicationDelegate with NSStatusBar.system.statusItem
