# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GarminCoach is an iOS app (SwiftUI, iOS 17+, Swift 5.9) that reads running workouts and health metrics from Apple Health, builds a structured coaching prompt, and calls the Anthropic API (Claude Opus 4.7) to return personalized training insights.

## Build & Run

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`. If you modify `project.yml`, regenerate before opening Xcode:

```bash
xcodegen generate
open GarminCoach.xcodeproj
```

Build and run on a physical device or simulator from Xcode (`Cmd+R`). There are no test targets yet.

Before first run you must:
1. Set a valid `DEVELOPMENT_TEAM` in `project.yml` (or Xcode project settings).
2. Update `PRODUCT_BUNDLE_IDENTIFIER` if needed.
3. Enter an Anthropic API key in the app's Settings tab — it is stored in the iOS Keychain.

## Architecture

The data flow for a coaching request is strictly linear:

```
HealthKitManager → WorkoutSummary / AthleteMetrics
       ↓
CoachingContextBuilder.build(runs:metrics:)  →  plain-text prompt string
       ↓
ClaudeService.getCoachingInsight(prompt:)    →  calls api.anthropic.com
       ↓
CoachingView (displays result)
```

**Key files:**
- `Services/HealthKitManager.swift` — all HealthKit queries; read-only, no writes. Fetches last 20 runs, resting HR (7-day avg), VO2max (latest), and body weight (latest) in parallel.
- `Models/TrainingModels.swift` — `WorkoutSummary` and `AthleteMetrics` value types; no persistence.
- `Utilities/CoachingContextBuilder.swift` — formats health data into a markdown prompt with weekly volume, recent runs (with HR zone annotation), and athlete metrics. Heart-rate zones are hardcoded for HRmax=191 bpm using a dual-threshold 5-zone model.
- `Services/ClaudeService.swift` — thin HTTP wrapper around `api.anthropic.com/v1/messages`. API key is loaded from Keychain via `KeychainHelper`. System prompt is defined here.
- `Utilities/KeychainHelper.swift` — Keychain read/write/delete for the Anthropic API key (`kSecClassGenericPassword`).
- `Views/CoachingView.swift` — single-button UI; fires `HealthKitManager` + `ClaudeService` concurrently via `async let`, surfaces errors inline.
- `Views/SettingsView.swift` — API key entry (stored to Keychain), key deletion, and static metadata display.

## Important Constraints

- **HealthKit is read-only.** The entitlements declare `toShare: []`; never add write permissions without explicit intent.
- **API key lives in Keychain only.** It is never logged, stored in UserDefaults, or embedded in code.
- **Heart-rate zone boundaries are athlete-specific** (HRmax=191, LT1≈162, LT2≈181). Any changes to zones must be kept consistent between `CoachingContextBuilder.hrZone(_:)` and the system prompt in `ClaudeService`.
- The Xcode project is generated from `project.yml` (XcodeGen). Do not hand-edit `GarminCoach.xcodeproj/project.pbxproj` — changes will be overwritten on the next `xcodegen generate`.
