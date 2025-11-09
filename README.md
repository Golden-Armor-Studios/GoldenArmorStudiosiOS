# Golden Armor Studio (iOS)

Native iOS client for the Golden Armor Studio platform. The project is built in Swift and integrates Firebase services for authentication, analytics, storage, and more.

## Requirements
- Xcode 15 or newer (tested with Xcode 26.0.1)
- iOS 16+ deployment target
- Swift Package Manager for third-party dependencies (Firebase SDKs)

## Project Structure
- `Golden Armor Studio/` – Application sources, assets, and resources.
  - `Classes/` – View controllers, views, and session/auth management.
  - `Delegates/` – `AppDelegate` and `SceneDelegate`.
  - `Assets.xcassets/` – Image assets and app icons.
  - `Base.lproj/` – Storyboards and nibs.
  - `Videos/` – Background promo/media assets.
- `Golden Armor Studio.xcodeproj` – Xcode project configuration.
- `Info.plist` – App metadata (bundle ID, fonts, URL schemes).

## Firebase Configuration
Place the appropriate `GoogleService-Info.plist` in `Golden Armor Studio/` (already included). Verify that the bundle ID matches your Firebase project configuration before building.

## Building
```bash
xcodebuild -scheme "Golden Armor Studio" -configuration Debug -sdk iphonesimulator build
```
Or open the project in Xcode and build/run on the simulator of your choice.

## Git
This repository uses `.gitattributes` to normalize line endings and mark binary assets, and `.gitignore` to exclude build artifacts.
