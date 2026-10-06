# BodyTrainer

Weigh-in tracker for iPhone. The reminder is a notification you type into: hold or pull it down, enter `196.4`, tap **Log**. The weight goes to Apple Health (Body Weight) and the app's log without opening the app.

- **Inline reply**: `UNTextInputNotificationAction` on Mon/Wed/Fri 7:00 (days and time are editable in the app)
- **Apple Health**: every weigh-in is written as `HKQuantityType(.bodyMass)`; the last year of Health weights is imported on first run
- **Live Activity**: the latest weight and change vs. a week ago, on the Lock Screen and in the Dynamic Island
- **Siri / Shortcuts**: "Log my weight in BodyTrainer"
- SwiftUI + SwiftData + HealthKit + ActivityKit, iOS 26, XcodeGen

## Install

https://assiamahs.github.io/bodytrainer/install.html. Open it in Safari on a registered iPhone.

## Build

CI only (`.github/workflows/ci.yml`): an unsigned compile check, then an unsigned archive and an ad hoc export signed in the cloud. The IPA and manifest are committed to `web/ipa/` and deployed to Pages. Build number = workflow run number; `MARKETING_VERSION` in `project.yml` + a `vX.Y.Z` tag per release.
