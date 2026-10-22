# BrickSweep Plan

## Current Status

BrickSweep is live on the App Store. The original MVP is complete, the post-launch onboarding and reliability work has been implemented, and automatic theme grouping is the current release target.

The app currently includes:

- Paginated Rebrickable set and minifigure imports, including progress, retry, and partial-load recovery.
- Local SwiftData storage for sets, parts, missing quantities, replacement quantities, and theme metadata.
- Per-set and collection-wide missing-parts views.
- Search, filtering, sorting, completion summaries, and replacement tracking.
- BrickLink XML and CSV export.
- A five-set free tier and a one-time Pro unlock for unlimited sets and export.
- Keychain storage and verification of the user's Rebrickable API key before imports.

The original explicit Done/Submit workflow is no longer needed. Part changes now persist directly through SwiftData, and collection-wide missing and replaced totals are derived from stored parts when displayed.

## Release Roadmap

### 1.0.1 - Launch Polish and Trust

**Status: Implemented**

- Removed temporary StoreKit diagnostic logging from production flows.
- Added a feedback/contact entry point in Settings.
- Improved API-key setup, validation, error messages, and help.
- Added a lightweight example-set path that is available only after a key has been validated.
- Improved paywall product-loading, retry, restore, and unavailable states.
- Kept analytics out of the app.

The App Store review prompt was deliberately deferred. It should be added only after there is enough usage to choose a respectful trigger.

### 1.1 - Automatic Theme Grouping

**Status: Implemented locally; final testing and release still required**

- Store Rebrickable theme metadata when a set is imported.
- Resolve imported sets to their top-level theme rather than exposing subthemes such as Police.
- Add All and Themes browsing modes to the Sets tab.
- Show per-theme set, part, and missing-part summaries.
- Keep theme grouping in the free experience.
- Backfill missing theme metadata for existing users when they open Themes.
- Use text-only theme rows rather than invented theme artwork or generic icons.

Before release:

- Test migration using a copy of a live-version SwiftData store.
- Test theme backfill with a valid key, no key, and interrupted network access.
- Check empty, loading, error, and populated theme views on supported iPhone sizes.
- Commit the implementation and prepare focused release notes.

### 1.2 - Custom Collections

**Status: Not started**

Goal: match how people organise physical collections, such as shelves, tubs, children, resale stock, or rebuild projects.

- Add user-created collections.
- Allow a set to belong to one or more collections.
- Add collection-level missing-part totals and completion summaries.
- Free: one custom collection.
- Pro: unlimited custom collections and collection-scoped export.

### 1.3 - Find in Collection

**Status: Not started**

Goal: answer: "I lost this part. Do I already own it in another set?"

- Open Find in Collection from a part row or detail view.
- Match by part number and colour across owned sets.
- Show matching sets, quantities, and whether those sets already have missing pieces.
- Keep the first version informational; do not add transfer or reservation state yet.
- Free: search across free-tier sets.
- Pro: search the full collection and custom collections.

### 1.4 - Bulk Import

**Status: Not started**

- Accept multiple set numbers pasted one per line.
- Import sequentially with visible progress and rate-limit-friendly pacing.
- Preserve successful imports and clearly identify failures that can be retried.
- Treat bulk import as a Pro workflow for larger collections.

## Later Candidates

- A well-timed App Store review prompt.
- Import from a user's Rebrickable collection after a reliable user-token flow is designed.
- Additional missing-part lifecycle states such as exported and ordered. Replaced is already implemented.
- Saved missing lists for projects or orders.
- Direct BrickLink API integration only if demand justifies the added authentication and maintenance.
- iPad support if there is clear user demand.

Cloud sync, collection-value tracking, and analytics should remain out of scope until user feedback demonstrates a concrete need.
