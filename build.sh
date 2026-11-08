#!/bin/zsh
# BatStats — Battery Status
# Copyright (c) 2026 @utama_wira. Lisensi MIT.
#
# Build BatStats.app dan (opsional) pasang ke /Applications.
#   ./build.sh            -> build saja (hasil: build/BatStats.app)
#   ./build.sh install    -> build + salin ke /Applications + jalankan
set -e
cd "$(dirname "$0")"

VERSION=2.2
APP=build/BatStats.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14" \
  -framework AppKit -framework SwiftUI Sources/*.swift -o "$APP/Contents/MacOS/BatStats"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>BatStats</string>
  <key>CFBundleDisplayName</key><string>BatStats</string>
  <key>CFBundleIdentifier</key><string>io.github.utama-wira.batstats</string>
  <key>CFBundleExecutable</key><string>BatStats</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleGetInfoString</key><string>BatStats — Battery Status</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 @utama_wira. Lisensi MIT.</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "✓ Build selesai: $PWD/$APP"

if [[ "$1" == "install" ]]; then
  # Hentikan & hapus versi lama (BateraiKu) jika ada.
  pkill -x BateraiKu 2>/dev/null || true
  rm -rf /Applications/BateraiKu.app

  pkill -x BatStats 2>/dev/null || true
  rm -rf /Applications/BatStats.app
  cp -R "$APP" /Applications/
  open /Applications/BatStats.app
  echo "✓ Terpasang di /Applications dan sudah berjalan (lihat menu bar)."
fi
