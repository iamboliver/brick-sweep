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
| Destination | `platform=iOS Simulator,name=iPhone 18 Pro Max,OS=27.2` |
| Derived data | `build/DerivedData` |
| Result bundle | `build/TestResults/<scope>-<UTC timestamp>.xcresult` |
| Raw log | Same path as the result bundle, ending `.log` |
| Results and coverage | Same path, ending `-summary.json` (pass/fail counts and failures) and `-coverage.json` (per-target coverage) |
| Simulator | One device for everything in this repo, tests and App Store screenshots alike. The script boots it, and shuts it down afterwards if it wasn't already running |
| Signing | Off (`CODE_SIGNING_ALLOWED=NO`); simulator builds don't need it and CI has no identity |
| CI runner | GitHub-hosted `xcode-27` image, which has Xcode 27.2 and the iPhone 18 Pro Max on iOS 27.2 |

`build/` is gitignored. Each run writes a new result bundle because `xcodebuild` won't overwrite one, so old bundles collect in `build/TestResults/` until you delete them.

Console output goes through `xcbeautify` when it is installed (CI has it). `xcbeautify` doesn't show all Swift Testing output, so the script also saves the raw `xcodebuild` output as the `.log` file. It finishes with a summary: pass, fail and skip counts from the result bundle, which cover Swift Testing and XCTest alike (for example `Tests: 123 passed, 0 failed, 0 skipped (Passed)`), then whether the run succeeded. In GitHub Actions it also writes that summary to the run's summary page.

Open a result bundle in Xcode to see failures, logs and attachments:

```bash
open build/TestResults/unit-20261123-164835.xcresult
```

## When tests fail

The script collects what's needed to diagnose a failure without rerunning it, in a `-diagnostics` folder beside the result bundle:

| File | Contents |
|-|-|
| `failures.md` | A table of each failed test: its target, identifier and failure message. If no test failed, the build did, and this lists the build errors instead |
| `attachments/` | Screen recordings and screenshots that failed UI tests kept (`manifest.json` maps them to tests) |
| `simulator.log` | Errors and faults that the app and the UI test runner logged in the simulator during the run |
| `crashes/` | Crash reports for the app written during the run, if any |

The failure table is also printed at the end of the run and, in GitHub Actions, added to the run's summary page. There, `xcbeautify` also turns each failure into an annotation on the run and on the pull request's changes.

Coverage is recorded on every run, pass or fail.

## Continuous integration

`.github/workflows/tests.yml` runs `scripts/test.sh unit` on every pull request and on every push to `main`. It:

- uses the `xcode-27` runner and the shared `.github/actions/setup-toolchain` action, which selects Xcode 27.2 with `DEVELOPER_DIR` (the image defaults to 27.1) and installs a pinned XcodeGen release (2.44.1) after checking its SHA-256
- needs no secrets; the unit tests use mock clients and stores and make no network calls
- fails the check if the project won't generate, the build fails or any test fails
- uploads `build/TestResults` (result bundle, raw log, summary, coverage and diagnostics) and `build/DerivedData/Logs` as the `unit-test-results` artifact when a run fails

A newer push to a pull request cancels the run already going for it. Every push to `main` gets its own run that is never cancelled, so each commit on `main` is tested even when several land within one run.

### Artifact retention

Artifacts are kept for 14 days (`retention-days: 14` in both workflows), well under the repository's default of 90, and then deleted by GitHub. The unit-test workflow uploads only when a run fails. A failing UI run is larger, about 15 MB, mostly its screen recording. Download a run's artifact from its page, or with `gh run download <run id>`.

To bump XcodeGen, update `XCODEGEN_VERSION` and `XCODEGEN_SHA256` in `.github/actions/setup-toolchain/action.yml` together (`shasum -a 256 xcodegen.zip` on the release's `xcodegen.zip`).

## Remote test runs

`.github/workflows/remote-tests.yml` runs `scripts/test.sh` on demand. Start it from the Actions tab (**Remote tests** > **Run workflow**), or from any machine with the GitHub CLI or REST API, with no SSH access to a Mac needed.

| Input | Default | Passed to the script as |
|-|-|-|
| `ref` | `main` | The branch, tag or commit that is checked out and tested |
| `scope` | `unit` | Its argument: `unit`, `ui` or `all` |
| `simulator_name` | `iPhone 18 Pro Max` | `SIMULATOR_NAME` |
| `simulator_os` | `27.2` | `SIMULATOR_OS` |
| `verbose` | `false` | `VERBOSE=1`: raw `xcodebuild` output in the job log instead of `xcbeautify`'s |
| `request_id` | empty | Not passed; it's added to the run name so a caller can find its run |

The run name shows the scope, ref and request ID (`Remote tests: ui on main nightly-42`), and the run's summary page lists every input, the commit tested and the test summary. Results are uploaded as the `test-results-<scope>` artifact on every run, pass or fail, and kept for 14 days. The artifact holds `build/TestResults` (result bundle, raw log, summary, coverage and, on failure, diagnostics) and `build/DerivedData/Logs`.

A ref older than `scripts/test.sh` and the shared toolchain action can't be tested this way; the run fails straight away and says so.

### From the GitHub CLI

The caller needs a token with **Actions: read and write** on this repository (a fine-grained personal access token works; export it as `GH_TOKEN`).

```bash
# Start a run. The CLI prints the new run's URL.
gh workflow run remote-tests.yml --repo iamboliver/brick-sweep \
  -f ref=my-branch -f scope=ui -f request_id=nightly-42

# Find it by request ID, then wait for it. --exit-status makes watch fail if the tests fail.
run_id=$(gh run list --repo iamboliver/brick-sweep --workflow remote-tests.yml \
  --json databaseId,displayTitle --jq '.[] | select(.displayTitle | endswith("nightly-42")) | .databaseId' | head -1)
gh run watch "$run_id" --repo iamboliver/brick-sweep --exit-status

# Check its status at any time, and download the results.
gh run view "$run_id" --repo iamboliver/brick-sweep --json status,conclusion
gh run download "$run_id" --repo iamboliver/brick-sweep --dir results
```

### From the REST API

```bash
curl -fsS -X POST \
  -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/iamboliver/brick-sweep/actions/workflows/remote-tests.yml/dispatches \
  -d '{"ref": "main", "inputs": {"ref": "my-branch", "scope": "ui", "request_id": "nightly-42"}}'
```

The top-level `"ref"` is the branch whose copy of the workflow file runs; keep it `main`. `inputs.ref` is the code that gets tested. Poll `GET /repos/iamboliver/brick-sweep/actions/workflows/remote-tests.yml/runs` and match `display_title` on the request ID to find the run. Then use `GET .../actions/runs/{id}` for status and `GET .../actions/runs/{id}/artifacts` for the results.

## Overrides

Set these environment variables to change the defaults:

| Variable | Default | Use |
|-|-|-|
| `SIMULATOR_NAME` | `iPhone 18 Pro Max` | Run on another device |
| `SIMULATOR_OS` | `27.2` | Run on another iOS runtime |
| `DERIVED_DATA_PATH` | `build/DerivedData` | Share a build cache |
| `RESULT_BUNDLE_PATH` | timestamped, see above | Write the result bundle to a fixed path (CI does this so it can upload it) |
| `VERBOSE` | `0` | `1` prints raw `xcodebuild` output instead of `xcbeautify`'s |
| `KEEP_SIMULATOR` | `0` | `1` leaves the simulator running afterwards, which saves the boot when running the tests repeatedly |

```bash
KEEP_SIMULATOR=1 scripts/test.sh ui
```

Please stick to the default simulator rather than booting others; several running simulators slow the machine down badly.

## When the environment is wrong

The script checks the toolchain before building and says what to fix:

- **No `xcodegen` or `xcodebuild`**: it fails and says what to install.
- **Different Xcode selected**: it warns, then carries on, since a newer Xcode often works. Switch with `sudo xcode-select -s /Applications/Xcode_27.2.app` or set `DEVELOPER_DIR` for one run.
- **Simulator missing**: it fails, lists the iPhone simulators you do have, and gives the `xcrun simctl create` command for the right device, plus where to install the iOS runtime (Xcode > Settings > Components) if that's missing too.

## Updating the toolchain

When moving to a new Xcode, change `REQUIRED_XCODE` and the default simulator in `scripts/test.sh`, the runner image in both workflows, the Xcode selected in `.github/actions/setup-toolchain/action.yml`, the `simulator_os`/`simulator_name` defaults in `remote-tests.yml`, and the table above, in the same pull request. Check that the runner image has the new Xcode and simulator first; GitHub lists what each image contains in [actions/runner-images](https://github.com/actions/runner-images/tree/main/images/macos).
