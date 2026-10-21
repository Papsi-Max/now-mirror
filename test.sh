#!/bin/zsh
# Runs the unit tests (state merging, artwork scaling, shared model).
set -e
cd "${0:A:h}"
xcodegen generate --quiet
xcodebuild -project NowMirror.xcodeproj -scheme NowMirror -configuration Debug \
  -derivedDataPath build/derived-test CODE_SIGN_IDENTITY=- test | grep -E "error:|Executed|TEST (SUCCEEDED|FAILED)"
# The test build also produces an app with the widget: unregister and delete it, or macOS keeps
# picking that stale copy as the widget provider.
LSR=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
$LSR -u build/derived-test/Build/Products/Debug/NowMirror.app 2>/dev/null || true
rm -rf build/derived-test
