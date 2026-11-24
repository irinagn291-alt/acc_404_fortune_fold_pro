#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
kind="${1:?phone or pad}"
label="${2:-$kind}"
derived="${FF_DERIVED_ROOT:-/tmp/acc404-motion-derived}-$kind"
evidence="${FF_EVIDENCE_ROOT:?Set FF_EVIDENCE_ROOT outside the project}"
raw="${FF_RAW_ROOT:?Set FF_RAW_ROOT for raw attachments}"
mkdir -p "$evidence" "$raw"
result="$evidence/$label.xcresult"

xcrun simctl boot "$GF_SIMULATOR_UDID"
xcrun simctl bootstatus "$GF_SIMULATOR_UDID" -b

if [[ "$kind" == phone ]]; then
  method=testPhoneCampaignAndRestoration
elif [[ "$kind" == clip ]]; then
  method=testStreamClip
  derived="${FF_DERIVED_ROOT:-/tmp/acc404-motion-derived}-phone"
elif [[ "$label" == ipad-motion-final ]]; then
  method=testPadMotionReview
else
  method=testPadArabic
fi

if [[ "$kind" == clip || ( "$kind" == phone && "${3:-record}" == record ) ]]; then
  python3 -c 'import time; print(time.time())' > "$evidence/$label-recording-epoch.txt"
  xcrun simctl io "$GF_SIMULATOR_UDID" recordVideo --codec=h264 --force "$raw/$label-recording-full.mp4" > "$evidence/$label-recording.log" 2>&1 &
  recorder=$!
  trap 'kill -INT "$recorder" 2>/dev/null || true; wait "$recorder" || true' EXIT
fi

if [[ "$method" == testPadMotionReview ]]; then
  (
    while ! rg -q 'FF_CAPTURE SHADOW_READY' "$evidence/$label.log" 2>/dev/null; do
      sleep 0.12
    done
    sleep 0.65
    for frame in 01 02 03 04 05 06 07 08 09 10 11 12; do
      xcrun simctl io "$GF_SIMULATOR_UDID" screenshot "$raw/$label-shadow-$frame.png" >/dev/null 2>&1
      sleep 0.14
    done
  ) &
  watcher=$!
  trap 'kill "$watcher" 2>/dev/null || true; wait "$watcher" 2>/dev/null || true' EXIT
fi

set +e
xcodebuild -project FortuneFold.xcodeproj -scheme FortuneFold -destination "id=$GF_SIMULATOR_UDID" \
  -parallel-testing-enabled NO -derivedDataPath "$derived" -resultBundlePath "$result" \
  -only-testing:"FortuneFoldUITests/FortuneFoldUITests/$method" -jobs 4 test > "$evidence/$label.log" 2>&1
test_status=$?
set -e
if [[ "$kind" != pad ]]; then
  xcrun simctl spawn "$GF_SIMULATOR_UDID" log show --last 20m --info --style compact \
    --predicate 'eventMessage BEGINSWITH "FF_AUDIO "' > "$evidence/$label-audio-events.log" || true
fi

if [[ -d "$result" ]]; then
  xcrun xcresulttool export attachments --path "$result" --output-path "$raw/$label-attachments"
fi
product="$derived/Build/Products/Debug-iphonesimulator/FortuneFold.app"
if [[ -f "$product/FortuneFold" && "$test_status" == 0 ]]; then
  find "$derived/Build/Intermediates.noindex/FortuneFold.build" -path '*/FortuneFold.build/*FortuneFold.SwiftFileList' -exec cat {} \; |
    sort -u > "$evidence/$label-compiled-sources.txt"
  find "$product" -type f | sed "s|^$product/||" | sort > "$evidence/$label-bundle.txt"
fi
exit "$test_status"
