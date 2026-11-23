#!/usr/bin/env bash
# Runs the BrickSweep tests the same way locally and in GitHub Actions.
# See docs/testing.md for the contract this script implements.
#
#   scripts/test.sh            # unit tests (BrickSweepTests)
#   scripts/test.sh ui         # UI tests (BrickSweepUITests)
#   scripts/test.sh all        # both
#
# Overrides (environment):
#   SIMULATOR_NAME     default "iPhone 18 Pro"
#   SIMULATOR_OS       default "27.2"
#   DERIVED_DATA_PATH  default build/DerivedData
#   RESULT_BUNDLE_PATH default build/TestResults/<scope>-<UTC timestamp>.xcresult
#   VERBOSE            1 prints raw xcodebuild output instead of xcbeautify's summary

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

simulator_name="${SIMULATOR_NAME:-iPhone 18 Pro}"
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
if ! xcrun simctl list devices available | awk -v os="-- iOS $simulator_os --" -v name="$simulator_name" '
    /^-- / { in_os = ($0 == os); next }
    in_os && index($0, "    " name " (") == 1 { found = 1 }
    END { exit !found }'; then
    echo "error: no '$simulator_name' simulator on iOS $simulator_os. Available iPhones:" >&2
    xcrun simctl list devices available | awk '
        /^-- / { os = $0; gsub(/-- | --/, "", os); next }
        /iPhone/ { sub(/^ +/, ""); print "  " os ": " $0 }' >&2
    fail "install the iOS $simulator_os runtime in Xcode > Settings > Components, or set SIMULATOR_NAME/SIMULATOR_OS"
fi

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
    ${only_testing[@]+"${only_testing[@]}"}
    CODE_SIGNING_ALLOWED=NO
)

formatter=(cat)
if [[ "${VERBOSE:-0}" != 1 ]] && command -v xcbeautify >/dev/null; then
    formatter=(xcbeautify)
fi

# xcbeautify drops some Swift Testing output, so keep the raw log and repeat its summary.
log="${result_bundle%.xcresult}.log"
status=0
"${test_command[@]}" 2>&1 | tee "$log" | "${formatter[@]}" || status=$?

# Swift Testing (unit) and XCTest (UI) each print their own count; the last XCTest
# "Executed" line is the total across its suites.
summary="$(
    grep -E 'Test run with [0-9]+ tests' "$log" || true
    grep -E '^[[:space:]]*Executed [1-9][0-9]* tests?,' "$log" | tail -1 | sed -E 's/^[[:space:]]*/XCTest: /' || true
    grep -E '\*\* (TEST|BUILD) (SUCCEEDED|FAILED)' "$log" || true
)"

echo
echo "$summary"
echo "Full log: $log"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '### %s tests\n\n```\n%s\n```\n' "$scope" "$summary" >> "$GITHUB_STEP_SUMMARY"
fi

exit "$status"
