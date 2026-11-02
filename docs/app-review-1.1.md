# App Review notes for BrickSweep 1.1

Users who first downloaded BrickSweep 1.0 receive BrickSweep Pro at no cost, permanently, as a thank-you for being here early. This unlocks unlimited sets and export. Existing Pro purchases continue to work. New users retain the five-set free tier and can buy the existing one-time Pro purchase.

Eligibility uses the verified StoreKit 2 AppTransaction originalAppVersion, parsed as a whole-number iOS build and compared to the last founding build, `6` (eligible when at or below `6`). Version 1.0 shipped as build `6`; noninteger values are not eligible. The App Store install record preserves eligibility across reinstalls and new devices. A verified result is cached for offline launches and checked again at launch, foreground activation, and Restore Purchases. Settings identifies eligible users as founding members.

## Release validation

The bs-91d version bump must land before release: the shipped CFBundleVersion must be greater than `6` (bs-91d sets build `7`). The StoreManager release-build test deliberately fails if this prerequisite is absent.

On a device with an App Store 1.0 install, update to 1.1 and verify the founding-member message, unlimited sets, export access without a paywall, and access after relaunching offline. Verify reinstalls and a second device with the same Apple ID. A fresh 1.1 install must retain the five-set limit and normal export paywall. Also verify an existing Pro buyer retains access.

Sandbox and TestFlight report originalAppVersion `1.0`, which is not eligible. For local DEBUG builds, set the Xcode scheme environment variable `BRICKSWEEP_FOUNDING_USER` to `1` (founder) or `0` (non-founder); remove it to use StoreKit. This override does not write to the verified cache and is absent from Release builds. Non-founder simulation does not override an actual Pro purchase.

Reference: [Apple originalAppVersion documentation](https://developer.apple.com/documentation/storekit/apptransaction/originalappversion).
