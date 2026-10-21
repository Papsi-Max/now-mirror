#!/bin/zsh
# Produces dist/NowMirror-<version>.dmg and .zip from build/NowMirror.app (ad-hoc signed).
set -e
cd "${0:A:h}"
[ -d build/NowMirror.app ] || ./build.sh
V=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/NowMirror.app/Contents/Info.plist)
rm -rf dist && mkdir -p dist/dmg
cp -R build/NowMirror.app dist/dmg/
ln -s /Applications dist/dmg/Applications
hdiutil create -quiet -volname "Now Mirror" -srcfolder dist/dmg -ov -format UDZO "dist/NowMirror-$V.dmg"
ditto -c -k --sequesterRsrc --keepParent build/NowMirror.app "dist/NowMirror-$V.zip"
rm -rf dist/dmg
shasum -a 256 dist/NowMirror-$V.* | tee dist/SHA256SUMS
