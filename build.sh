#!/bin/zsh
# Builds the adapter (clang), generates the project (xcodegen), builds (xcodebuild) and ad-hoc signs.
set -e
cd "${0:A:h}"
A=vendor/mediaremote-adapter
[ -d $A ] || git clone https://github.com/ungive/mediaremote-adapter.git $A
# Adapter version this app was tested with (pinned); leave empty to follow the default branch.
PIN="0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd"
[ -z "$PIN" ] || git -C $A checkout --quiet $PIN
F=$A/build/MediaRemoteAdapter.framework
if [ ! -d $F ]; then
  mkdir -p $F/Versions/A/{Headers,Resources}
  clang -dynamiclib -fobjc-arc -fvisibility=default -arch arm64 -arch x86_64 -I$A/include -I$A/src \
    -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
    -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
    $A/src/adapter/*.m $A/src/private/MediaRemote.m $A/src/utility/*.m -o $F/Versions/A/MediaRemoteAdapter
  cp $A/include/MediaRemoteAdapter.h $F/Versions/A/Headers/
  cat > $F/Versions/A/Resources/Info.plist <<'P'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>MediaRemoteAdapter</string><key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleVersion</key><string>0.1.0</string><key>CFBundleShortVersionString</key><string>0.1</string></dict></plist>
P
  ln -sfn A $F/Versions/Current
  for l in MediaRemoteAdapter Headers Resources; do ln -sfn Versions/Current/$l $F/$l; done
  codesign --force --deep --sign - $F
  clang -fobjc-arc -arch arm64 -arch x86_64 -I$A/src/test -framework Foundation -framework MediaPlayer \
    $A/src/test/main.m $A/src/test/NowPlayingTest.m -o $A/build/MediaRemoteAdapterTestClient
  codesign --force --sign - $A/build/MediaRemoteAdapterTestClient
fi
xcodegen generate --quiet
xcodebuild -project NowMirror.xcodeproj -scheme NowMirror -configuration Release \
  -derivedDataPath build/derived CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build | tail -15
rm -rf build/NowMirror.app && cp -R build/derived/Build/Products/Release/NowMirror.app build/NowMirror.app
LSR=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
# Avoids a duplicate widget registration (DerivedData copy)
$LSR -u build/derived/Build/Products/Release/NowMirror.app 2>/dev/null || true
rm -rf build/derived/Build/Products/Release/NowMirror.app
$LSR -f build/NowMirror.app
echo "OK → build/NowMirror.app"
