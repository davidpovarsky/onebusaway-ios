#!/usr/bin/env bash
#
# Runs the automated Israel Map Zoom Stress UI Tests on an iPad simulator.
# Records video, captures xcresult, unified logs, and crash reports.
#

set -o pipefail

echo "=== [1/6] Generating Xcode Project for OneBusAway ==="
scripts/generate_project OneBusAway --no-watch

echo "=== [2/6] Resolving iPad Simulator UDID ==="
SIMULATOR_UDID=$(scripts/resolve_ipad_simulator_udid)
echo "Resolved iPad Simulator UDID: $SIMULATOR_UDID"

echo "=== [3/6] Booting iPad Simulator ==="
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

echo "=== [3.5/6] Disabling Stage Manager on iPad Simulator ==="
xcrun simctl spawn "$SIMULATOR_UDID" defaults write com.apple.SpringBoard SBStageManagerEnabled -bool false
xcrun simctl spawn "$SIMULATOR_UDID" defaults write com.apple.SpringBoard SBChamoisWindowingEnabled -bool false
xcrun simctl spawn "$SIMULATOR_UDID" defaults write com.apple.SpringBoard SBShowStageManagerInControlCenter -bool false
xcrun simctl spawn "$SIMULATOR_UDID" killall -9 SpringBoard 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

echo "=== [4/6] Setting Simulator Location to Jerusalem (31.790, 35.210) & Granting Privacy ==="
xcrun simctl location "$SIMULATOR_UDID" set 31.790,35.210
xcrun simctl privacy "$SIMULATOR_UDID" grant location-always org.onebusaway.iphone 2>/dev/null || true
xcrun simctl privacy "$SIMULATOR_UDID" grant location org.onebusaway.iphone 2>/dev/null || true
xcrun simctl privacy "$SIMULATOR_UDID" grant all org.onebusaway.iphone 2>/dev/null || true

# Continuous privacy/location supervisor daemon
(
  while true; do
    xcrun simctl privacy "$SIMULATOR_UDID" grant all org.onebusaway.iphone 2>/dev/null || true
    xcrun simctl location "$SIMULATOR_UDID" set 31.790,35.210 2>/dev/null || true
    sleep 2
  done
) &
LOCATION_DAEMON_PID=$!
echo "Continuous location and privacy supervisor started (PID: $LOCATION_DAEMON_PID)"

OUT_DIR="build/map-stress"
mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/Results.xcresult"

echo "=== [5/6] Starting Video Recording & Running Tests ==="
xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec=h264 "$OUT_DIR/simulator_run.mp4" &
RECORD_PID=$!
echo "Video recording started (PID: $RECORD_PID)"

TEST_ONLY_FLAGS=()
if [ "$RUN_ALL_TESTS" = "1" ]; then
  echo "=== Running Full Israel Map Zoom Stress Suite ==="
  TEST_ONLY_FLAGS+=(
    "-only-testing:OBAKitTests/IsraelMapStressProbeTests"
    "-only-testing:OBAKitUITests/IsraelMapZoomStressUITests"
  )
else
  echo "=== Running Fast Smoke Test First (Deadlock Unit Test + Classic Map Smoke) ==="
  TEST_ONLY_FLAGS+=(
    "-only-testing:OBAKitTests/IsraelMapStressProbeTests"
    "-only-testing:OBAKitUITests/IsraelMapZoomStressUITests/testJerusalemClassicMapSmoke"
  )
fi

TEST_EXIT_CODE=0
xcodebuild test \
  -project OBAKit.xcodeproj \
  -scheme App \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath DerivedData \
  -resultBundlePath "$OUT_DIR/Results.xcresult" \
  -parallel-testing-enabled NO \
  "${TEST_ONLY_FLAGS[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  2>&1 | tee "$OUT_DIR/xcodebuild.log" || TEST_EXIT_CODE=$?

echo "xcodebuild test exited with code: $TEST_EXIT_CODE"

echo "Stopping video recording and supervisor daemon..."
kill -INT "$RECORD_PID" 2>/dev/null || true
kill -9 "$LOCATION_DAEMON_PID" 2>/dev/null || true
wait "$RECORD_PID" 2>/dev/null || true

echo "=== [6/6] Collecting Diagnostic Artifacts & Crash Reports ==="
CRASH_DIR="$OUT_DIR/crashes"
mkdir -p "$CRASH_DIR"
find ~/Library/Logs/DiagnosticReports -type f \( -name "*OneBusAway*" -o -name "*App*" -o -name "*xctest*" \) -exec cp {} "$CRASH_DIR/" \; 2>/dev/null || true
find ~/Library/Developer/CoreSimulator/Devices/"$SIMULATOR_UDID"/data/Library/Logs/DiagnosticReports -type f -exec cp {} "$CRASH_DIR/" \; 2>/dev/null || true

# Capture simulator screenshot and process stack sample if needed
xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUT_DIR/simulator_final_state.png" 2>/dev/null || true
if [ "$TEST_EXIT_CODE" -ne 0 ]; then
  echo "Attempting to sample App process stack..."
  xcrun simctl spawn "$SIMULATOR_UDID" sample App 3 10 -file "$OUT_DIR/app_sample.txt" 2>/dev/null || true
fi

CRASH_COUNT=$(find "$CRASH_DIR" -type f | wc -l | tr -d ' ')
echo "Collected $CRASH_COUNT crash reports in $CRASH_DIR"
if [ "$CRASH_COUNT" -gt 0 ]; then
  echo "--- Crash Reports Found ---"
  ls -la "$CRASH_DIR"
fi

echo "Extracting app unified log..."
xcrun simctl spawn "$SIMULATOR_UDID" log show \
  --predicate 'process == "App" OR process == "OneBusAway" OR subsystem CONTAINS "onebusaway" OR message CONTAINS "STRESS"' \
  --last 60m > "$OUT_DIR/app_unified.log" 2>&1 || true

echo "Diagnostics collected in $OUT_DIR"
exit "$TEST_EXIT_CODE"
