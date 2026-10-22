# BrickSweep

BrickSweep is an iPhone app for checking brick-set completeness. Import a set from Rebrickable, mark missing pieces while checking the build, and combine missing parts from the whole collection into one replacement list.

## Why I Built This

I built BrickSweep for my autistic son, who loves building sets but often loses pieces. I wanted a quick way to see what was missing and prepare a replacement order without manually rebuilding a list elsewhere.

## Features

- **Import by set number** - load set details, inventory, and minifig parts from Rebrickable.
- **Reliable large-set loading** - paginated downloads, visible progress, partial results, and retry support.
- **Track missing parts** - adjust missing quantities directly from each part card.
- **Collection-wide missing list** - aggregate matching parts by part number and colour across every stored set.
- **Replacement tracking** - move obtained pieces to a separate Replaced view and undo when needed.
- **Theme browsing** - group sets automatically by their top-level Rebrickable theme, including metadata backfill for existing collections.
- **Completion summaries** - view quantity-based progress for each set and theme.
- **Search, filter, and sort** - find parts by identifiers and focus on missing or accounted-for pieces.
- **Pro export** - generate BrickLink Wanted List XML or CSV, then copy or share it.

The free tier stores up to five sets. BrickSweep Pro is a one-time, non-consumable purchase that unlocks unlimited set storage and export. Theme browsing and the core checking workflow remain free.

## Requirements

- iOS 18.0 or later
- Xcode 16.0 or later
- XcodeGen 2.38 or later
- A free [Rebrickable API key](https://rebrickable.com/api/)

BrickSweep currently targets iPhone only.

## Getting Started

```bash
git clone https://github.com/iamboliver/brick-sweep.git
cd brick-sweep
brew install xcodegen
xcodegen generate
open BrickSweep.xcodeproj
```

Run the `BrickSweep` scheme on an iPhone simulator or connected iPhone. On first launch, open Settings, enter a Rebrickable API key, and use Save and Test Key. Imports stay disabled until the key has been verified.

To build from the command line:

```bash
xcodebuild build \
  -project BrickSweep.xcodeproj \
  -scheme BrickSweep \
  -destination 'generic/platform=iOS'
```

## Architecture

BrickSweep uses SwiftUI, SwiftData, Swift concurrency, StoreKit 2, and a protocol-based URLSession networking layer. It has no third-party runtime dependencies.

```text
App/          App entry point, tab navigation, and StoreKit state
API/          Rebrickable client, protocol, errors, and DTOs
Models/       SwiftData entities and derived aggregate models
Services/     Import, theme, export, and colour-mapping logic
ViewModels/   Main-actor observable presentation state
Views/        SwiftUI screens grouped by feature
Utilities/    Keychain, constants, and shared helpers
Resources/    Asset catalogue and colour-mapping fallback data
```

Important implementation details:

- Rebrickable inventory pages are fetched in small requests with retry and request pacing.
- Part updates write directly to SwiftData; global missing and replaced lists are derived when displayed.
- API keys are stored in the Keychain and authenticated API responses are not cached.
- The StoreKit product is fetched using its exact App Store Connect identifier, and entitlements are refreshed at launch.
- Existing sets without theme metadata are refreshed when theme browsing is opened.

## Export Formats

Export is a BrickSweep Pro feature.

- **BrickLink XML** produces an `INVENTORY` document suitable for BrickLink's Wanted List upload flow.
- **CSV** includes part number, name, colour, missing quantity, and contributing set numbers.

## Running Tests

```bash
xcodebuild test \
  -project BrickSweep.xcodeproj \
  -scheme BrickSweep \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Tests cover API decoding, paginated imports and recovery, part deduplication, colour mapping, and XML/CSV export escaping and formatting.

## Roadmap

The next planned phases are custom collections, Find in Collection, and bulk import. Rebrickable collection sync is not currently available. See [plan.md](plan.md) for status and scope.

## Privacy

Collection data remains on the device. BrickSweep sends the user's API key and requested set identifiers to Rebrickable only when performing API operations. The app does not include analytics or advertising SDKs.

## Legal

LEGO is a trademark of the LEGO Group, which does not sponsor, authorise, or endorse this project. BrickLink and Rebrickable are independent services and are not affiliated with BrickSweep.
