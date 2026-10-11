#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVELOPER_PATH="$(xcode-select -p)"
TEST_FRAMEWORKS="$DEVELOPER_PATH/Library/Developer/Frameworks"
if [[ "$DEVELOPER_PATH" == */CommandLineTools && -d "$TEST_FRAMEWORKS/Testing.framework" ]]; then
    # CLT ships Swift Testing outside SwiftPM's default framework search path,
    # and some versions omit its optional Foundation cross-import overlay.
    swift test --disable-xctest \
        -Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker "-F$TEST_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS"
else
    swift test --disable-xctest
fi
