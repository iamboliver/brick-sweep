# BrickCheck

A native iOS app for tracking missing parts across your brick sets. Import sets from [Rebrickable](https://rebrickable.com), tap to mark pieces as missing, and export a BrickLink wanted list to order replacements.

# Why I build this

Built for my autistic son, who is obsessed with Lego but struggles to pack up sets. I needed a fast way to track what was missing and order replacements without spending an hour on BrickLink manually.

## Features

- **Import sets by number** — fetches set details, full parts inventory, and figures from the Rebrickable API
- **Tap-to-track missing parts** — tap a part card to increment the missing count; long-press for more options
- **Global missing parts view** — aggregates missing parts across all your sets, grouped by part and colour
- **Export to BrickLink** — generates BrickLink XML (wanted list format) or CSV, ready to copy or share
- **Completion tracking** — per-set progress rings and summary stats
- **Filter and sort** — filter by missing/accounted for, sort by colour or part number, search by part number or element ID
- **Rebrickable sync** — optionally add imported sets to your Rebrickable collection

## Screenshots

_Coming soon_

## Requirements

- iOS 18.0+
- Xcode 16.0+
- A free [Rebrickable API key](https://rebrickable.com/api/)

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/your-username/lego-missing-piece-tracker.git
cd lego-missing-piece-tracker
```

### 2. Generate the Xcode project

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install it if you haven't already:

```bash
brew install xcodegen
```

Then generate:

```bash
xcodegen generate
```

### 3. Build and run

Open `LegoMissingParts.xcodeproj` in Xcode, or build from the command line:

```bash
xcodebuild build -scheme LegoMissingParts -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 4. Add your API key

On first launch, go to the **Settings** tab and enter your Rebrickable API key. The key is stored securely in the Keychain.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Persistence | SwiftData |
| Networking | URLSession + async/await |
| Secrets | Keychain (Security framework) |
| Concurrency | Swift 6 strict concurrency |
| Project generation | XcodeGen |
| Testing | Swift Testing |

No third-party dependencies.

## Architecture

The app follows **MVVM** with `@Observable` view models:

```
App/                  → App entry point, TabView root
Models/               → SwiftData entities (LegoSet, LegoPartInstance, GlobalMissingPart)
Views/                → SwiftUI views, organised by tab
ViewModels/           → @MainActor @Observable view models
Services/             → Import, export, and colour mapping logic
API/                  → Protocol-based Rebrickable client + DTOs
Utilities/            → Keychain helper, colour sort order
Resources/            → Asset catalog, colour mapping fallback JSON
```

Key patterns:
- **Protocol-based API client** (`RebrickableAPIClientProtocol`) for testability
- **`@Bindable`** for direct SwiftData model mutation in views
- **Aggregate pattern** — `GlobalMissingPart.aggregate(from:)` groups parts by `(partNum, colorId)` across sets
- **BrickLink ID storage at import** — external IDs fetched once and persisted for offline export
- **Static JSON fallback** for Rebrickable-to-BrickLink colour mapping

## Export Formats

### BrickLink XML

Generates a `<INVENTORY>` XML file compatible with BrickLink's [Wanted List upload](https://www.bricklink.com/v2/wanted/upload.page). Part IDs and colour IDs are mapped to BrickLink's numbering system.

### CSV

Comma-separated file with part number, name, colour, quantity, and contributing set numbers.

## Running Tests

```bash
xcodebuild test -scheme LegoMissingParts -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Tests cover DTO decoding, export formatting (including XML/CSV escaping), and colour mapping fallback behaviour.

## Licence

LEGO is a trademark of the LEGO Group, which does not sponsor, authorise, or endorse this project. BrickLink and Rebrickable are independent services not affiliated with this project.
