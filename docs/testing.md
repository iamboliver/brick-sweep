# Testing

There is one way to run the tests: `scripts/test.sh`. Developers run it locally and GitHub Actions runs it in CI, so both use the same scheme, test targets, simulator and build settings.

## Running the tests

```bash
brew install xcodegen
scripts/test.sh          # unit tests (BrickSweepTests) - what pull requests run
scripts/test.sh ui       # UI tests (BrickSweepUITests)
scripts/test.sh all      # both
```

The script generates `BrickSweep.xcodeproj` with XcodeGen first, so there is no need to run `xcodegen generate` beforehand. It exits non-zero if the build or any test fails.

## The contract

| | Value |
|-|-|
| Xcode | 27.2 (build 27B52) |
| Scheme | `BrickSweep` |
| Test targets | `BrickSweepTests` (unit), `BrickSweepUITests` (UI) |
| Destination | `platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2` |
| Derived data | `build/DerivedData` |
| Result bundle | `build/TestResults/<scope>-<UTC timestamp>.xcresult` |
| Signing | Off (`CODE_SIGNING_ALLOWED=NO`); simulator builds don't need it and CI has no identity |
| CI runner | GitHub-hosted `xcode-27` image, which has Xcode 27.2 and the iPhone 18 Pro on iOS 27.2 |

`build/` is gitignored. Each run writes a new result bundle because `xcodebuild` won't overwrite one, so old bundles collect in `build/TestResults/` until you delete them.

Open a result bundle in Xcode to see failures, logs and attachments:

```bash
open build/TestResults/unit-20261123-164835.xcresult
```

## Overrides

Set these environment variables to change the defaults:

| Variable | Default | Use |
|-|-|-|
| `SIMULATOR_NAME` | `iPhone 18 Pro` | Run on another device |
| `SIMULATOR_OS` | `27.2` | Run on another iOS runtime |
| `DERIVED_DATA_PATH` | `build/DerivedData` | Share a build cache |
| `RESULT_BUNDLE_PATH` | timestamped, see above | Write the result bundle to a fixed path (CI does this so it can upload it) |

```bash
SIMULATOR_NAME="iPhone 18 Pro Max" scripts/test.sh ui
```

Remote runs should go through the same variables. The manually dispatched GitHub Actions workflow (bs-fpk.3) is to take them as inputs: `scope` is passed as the script's argument, and `simulator_name` and `simulator_os` become `SIMULATOR_NAME` and `SIMULATOR_OS`.

## When the environment is wrong

The script checks the toolchain before building and says what to fix:

- **No `xcodegen` or `xcodebuild`**: it fails and says what to install.
- **Different Xcode selected**: it warns, then carries on, since a newer Xcode often works. Switch with `sudo xcode-select -s /Applications/Xcode_27.2.app` or set `DEVELOPER_DIR` for one run.
- **Simulator or runtime missing**: it fails, lists the iPhone simulators you do have, and says how to install the runtime (Xcode > Settings > Components) or choose another device.

## Updating the toolchain

When moving to a new Xcode, change `REQUIRED_XCODE` and the default simulator in `scripts/test.sh`, the CI workflow's runner image and Xcode selection, and the table above, in the same pull request. Check that the runner image has the new Xcode and simulator first; GitHub lists what each image contains in [actions/runner-images](https://github.com/actions/runner-images/tree/main/images/macos).
