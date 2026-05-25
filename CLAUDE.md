# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GarminCoach is an iOS app (SwiftUI, iOS 17+, Swift 5.9) that displays Garmin training metrics and provides AI coaching by calling a home FastAPI server. All intelligence runs server-side; the app is a thin client.

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
3. Enter the server URL and token in the app's Settings tab — both are stored in the iOS Keychain.

## Architecture

The app has five tabs. Every tab calls the home server via `ServerClient`; no Anthropic API calls are made from the app directly.

```
User action (tap button / send message)
        ↓
ServerClient.shared.<method>()   →   POST/GET  home FastAPI server
        ↓
View updates with response
```

**Tabs and their server endpoints:**

| Tab | Endpoint | Notes |
|-----|----------|-------|
| Today | `GET /status` | Body Battery, HRV, Readiness, Sleep, RHR, Stress |
| Ask | `POST /chat` | Free-form coaching Q&A; history persisted in UserDefaults |
| Coach | `POST /coach` | Workout design; optional `upload: true` pushes to Garmin |
| Analyze | `POST /analyze` | Date-range training report; period formats: `YYYY-MM-DD`, `YYYY-MM-DD:YYYY-MM-DD`, `YYYY-MM` |
| Evaluate | `POST /evaluate` | Post-run assessment of most recent activity |

**Key files:**
- `Services/ServerClient.swift` — all HTTP calls; reads server URL and Bearer token from Keychain; defines all response types (`ServerStatus`, `CoachResponse`, `AnalyzeResponse`, `EvaluateResponse`, `ChatResponse`).
- `Utilities/KeychainHelper.swift` — Keychain read/write/delete for `serverURL` and `serverToken`.
- `Views/SettingsView.swift` — server URL and token entry, connection test (`GET /health`), stored to Keychain.
- `Views/StatusView.swift` — today's recovery metrics dashboard.
- `Views/ChatView.swift` — iMessage-style chat UI with typing indicator; saves/loads history via UserDefaults key `garmincoach_chat_history`.
- `Views/CoachingView.swift` — session-type picker (weekly / running / strength / lower-body / upper-body), upload toggle, displays uploaded workout list on success.
- `Views/AnalyzeView.swift` — date picker for Day / Week / Month / Custom, constructs the period string, displays markdown report.
- `Views/EvaluateView.swift` — single-button evaluate; displays monospaced report with activity date.
- `Views/Components.swift` — shared `MetricCard`, `SmallMetricCard`, `ErrorCard`, `LoadingCard`.
- `App/ContentView.swift` — `TabView` wiring all five tabs.
- `App/GarminCoachApp.swift` — `@main` entry point.

**Unused / legacy files (safe to delete):**
- `Services/HealthKitManager.swift` — HealthKit queries from v1; nothing in the current app calls this.
- `Models/TrainingModels.swift` — `WorkoutSummary` / `AthleteMetrics` value types used only by `HealthKitManager`.

## Important Constraints

- **API key lives in Keychain only.** The server token is never logged, stored in UserDefaults, or embedded in code.
- **No Anthropic SDK in the app.** All Claude calls are made server-side. Do not add `anthropic` as a dependency.
- **HealthKit entitlement is declared** (`com.apple.developer.healthkit: true`) but `toShare: []` — no writes. The HealthKit code is currently unused; re-enable only with explicit intent.
- The Xcode project is generated from `project.yml` (XcodeGen). Do not hand-edit `GarminCoach.xcodeproj/project.pbxproj` — changes will be overwritten on the next `xcodegen generate`.
- The server must be reachable at the configured URL (typically a Tailscale IP) for any tab to work. `ServerClient.isReachable()` hits `GET /health` with a 5-second timeout.
