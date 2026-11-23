#!/usr/bin/env bash
# Runs the BrickSweep tests the same way locally and in GitHub Actions.
# See docs/testing.md for the contract this script implements.
#
#   scripts/test.sh            # unit tests (BrickSweepTests)
#   scripts/test.sh ui         # UI tests (BrickSweepUITests)
#   scripts/test.sh all        # both
#
# Overrides (environment):
#   SIMULATOR_NAME     default "iPhone 18 Pro Max"
#   SIMULATOR_OS       default "27.2"
#   DERIVED_DATA_PATH  default build/DerivedData
#   RESULT_BUNDLE_PATH default build/TestResults/<scope>-<UTC timestamp>.xcresult
#   VERBOSE            1 prints raw xcodebuild output instead of xcbeautify's summary
#   KEEP_SIMULATOR     1 leaves the simulator running afterwards, to save the boot next time

set -euo pipefail

readonly REQUIRED_XCODE="27.2"
readonly SCHEME="BrickSweep"
readonly PROJECT="BrickSweep.xcodeproj"

cd "$(dirname "$0")/.."

fail() {
    echo "error: $*" >&2
    exit 1
}

scope="${1:-unit}"
case "$scope" in
    unit) only_testing=(-only-testing:BrickSweepTests) ;;
    ui) only_testing=(-only-testing:BrickSweepUITests) ;;
    all) only_testing=() ;;
    *) fail "unknown test scope '$scope' (expected unit, ui or all)" ;;
esac

# One simulator for everything in this repo (tests and App Store screenshots), so runs
# don't boot extra devices.
simulator_name="${SIMULATOR_NAME:-iPhone 18 Pro Max}"
simulator_os="${SIMULATOR_OS:-27.2}"
derived_data="${DERIVED_DATA_PATH:-build/DerivedData}"
# xcodebuild refuses to overwrite a result bundle, so each run gets its own.
result_bundle="${RESULT_BUNDLE_PATH:-build/TestResults/$scope-$(date -u +%Y%m%d-%H%M%S).xcresult}"

command -v xcodebuild >/dev/null || fail "xcodebuild not found; install Xcode $REQUIRED_XCODE"
command -v xcodegen >/dev/null || fail "xcodegen not found; run 'brew install xcodegen'"

xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
if [[ "$xcode_version" != "$REQUIRED_XCODE" ]]; then
    echo "warning: Xcode $xcode_version is selected but CI uses Xcode $REQUIRED_XCODE;" \
        "results may differ (select another with 'sudo xcode-select -s' or DEVELOPER_DIR)" >&2
fi

# The device must exist under the requested runtime, otherwise xcodebuild fails with a
# long, unhelpful destination error.
# Its UDID is kept for collecting the simulator's log if the tests fail.
simulator_udid="$(xcrun simctl list devices available | awk -v os="-- iOS $simulator_os --" -v name="$simulator_name" '
    /^-- / { in_os = ($0 == os); next }
    in_os && index($0, "    " name " (") == 1 && match($0, /\([0-9A-F]+-[0-9A-F-]+\)/) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
    }')"
if [[ -z "$simulator_udid" ]]; then
    echo "error: no '$simulator_name' simulator on iOS $simulator_os. Available iPhones:" >&2
    xcrun simctl list devices available | awk '
        /^-- / { os = $0; gsub(/-- | --/, "", os); next }
        /iPhone/ { sub(/^ +/, ""); print "  " os ": " $0 }' >&2
    fail "create it with: xcrun simctl create '$simulator_name' '$simulator_name' com.apple.CoreSimulator.SimRuntime.iOS-${simulator_os//./-}" \
        "(install the iOS $simulator_os runtime first in Xcode > Settings > Components if it is missing)"
fi

# Boot the simulator here rather than letting xcodebuild do it, so it is still running
# when diagnostics are collected. Shut it down afterwards if this script started it.
if ! xcrun simctl list devices | grep -q "($simulator_udid) (Booted)"; then
    if [[ "${KEEP_SIMULATOR:-0}" != 1 ]]; then
        trap 'xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true' EXIT
    fi
    echo "Booting '$simulator_name' (iOS $simulator_os)"
fi
xcrun simctl bootstatus "$simulator_udid" -b >/dev/null

# The project is generated, not committed.
xcodegen generate --quiet

mkdir -p "$(dirname "$result_bundle")"

echo "Testing scope=$scope on '$simulator_name' (iOS $simulator_os) with Xcode $xcode_version"
echo "Result bundle: $result_bundle"

# Simulator builds don't need a signing identity, and CI has none.
test_command=(
    xcodebuild test
    -project "$PROJECT"
    -scheme "$SCHEME"
    -destination "platform=iOS Simulator,name=$simulator_name,OS=$simulator_os"
    -derivedDataPath "$derived_data"
    -resultBundlePath "$result_bundle"
    -enableCodeCoverage YES
    ${only_testing[@]+"${only_testing[@]}"}
    CODE_SIGNING_ALLOWED=NO
)

formatter=(cat)
if [[ "${VERBOSE:-0}" != 1 ]] && command -v xcbeautify >/dev/null; then
    formatter=(xcbeautify)
    # In GitHub Actions, failures also become annotations on the run and the PR diff.
    [[ "${GITHUB_ACTIONS:-}" == true ]] && formatter+=(--renderer github-actions)
fi

# xcbeautify drops some Swift Testing output, so keep the raw log.
log="${result_bundle%.xcresult}.log"
started_at="$(date '+%Y-%m-%d %H:%M:%S')"
status=0
"${test_command[@]}" 2>&1 | tee "$log" | "${formatter[@]}" || status=$?

# The result bundle's counts cover Swift Testing and XCTest alike. The console's XCTest
# counts can't be trusted: after a UI test fails, the runner restarts and reports 0.
results="${result_bundle%.xcresult}-summary.json"
coverage="${result_bundle%.xcresult}-coverage.json"
if [[ -d "$result_bundle" ]]; then
    xcrun xcresulttool get test-results summary --path "$result_bundle" > "$results" 2>/dev/null || true
    # Coverage is recorded on every run; bs-fpk.1 builds a trend from it.
    xcrun xccov view --report --only-targets --json "$result_bundle" > "$coverage" 2>/dev/null || true
fi

summary="$(
    if [[ -s "$results" ]]; then
        jq -r '"Tests: \(.passedTests) passed, \(.failedTests) failed, \(.skippedTests) skipped (\(.result))"' "$results" || true
    fi
    grep -E '\*\* (TEST|BUILD) (SUCCEEDED|FAILED)' "$log" || true
)"

echo
echo "$summary"
echo "Full log: $log"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '### %s tests\n\n```\n%s\n```\n' "$scope" "$summary" >> "$GITHUB_STEP_SUMMARY"
fi

[[ "$status" == 0 ]] && exit 0

# Gather what's needed to diagnose the failure without reproducing it.
diagnostics="${result_bundle%.xcresult}-diagnostics"
mkdir -p "$diagnostics"

# Failed tests as a Markdown table, read from the result bundle. If there are none, the
# build failed, so list its errors instead.
report=""
if [[ -s "$results" ]]; then
    rows="$(jq -r '.testFailures[]? |
        "| \(.targetName) | `\(.testIdentifierString)` | \(.failureText | gsub("[\r\n]+"; " ") | gsub("\\|"; "\\|")) |"' \
        "$results")"
    if [[ -n "$rows" ]]; then
        report="$(printf '| Target | Test | Failure |\n|-|-|-|\n%s\n' "$rows")"
    fi
    # Only failed tests keep attachments. Their screen recordings and screenshots are the
    # useful part; the rest are binary records of synthesized input events.
    for pattern in '*.mp4' '*.png' '*.jpg' '*.jpeg' '*.heic'; do
        xcrun xcresulttool export attachments --path "$result_bundle" \
            --output-path "$diagnostics/attachments" --filter "$pattern" >/dev/null 2>&1 || true
    done
fi
if [[ -z "$report" ]]; then
    errors="$(grep -E '(^|: )error: ' "$log" | sort -u | head -20 || true)"
    report="$(printf 'No failed tests were recorded. Errors from the log:\n\n```\n%s\n```\n' "${errors:-none found; see the full log}")"
fi
printf '%s\n' "$report" > "$diagnostics/failures.md"

# Errors and faults the app and UI test runner logged in the simulator (everything else is
# framework noise, as the app doesn't use os.Logger), and any crash reports from the run.
xcrun simctl spawn "$simulator_udid" log show --start "$started_at" --style compact \
    --predicate '(process == "BrickSweep" OR process ENDSWITH "-Runner") AND (messageType == error OR messageType == fault)' \
    > "$diagnostics/simulator.log" 2>&1 || true
crashes="$(find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -name 'BrickSweep*' -newermt "$started_at" 2>/dev/null || true)"
if [[ -n "$crashes" ]]; then
    mkdir -p "$diagnostics/crashes"
    while IFS= read -r crash; do cp -f "$crash" "$diagnostics/crashes/"; done <<< "$crashes"
fi

echo
echo "$report"
echo "Diagnostics: $diagnostics"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '\n#### What failed\n\n%s\n\nThe result bundle, raw log, screen recordings of failed UI tests, simulator log and any crash reports are in this run'"'"'s test-results artifact.\n' \
        "$report" >> "$GITHUB_STEP_SUMMARY"
fi

exit "$status"
