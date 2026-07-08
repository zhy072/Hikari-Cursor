#!/bin/zsh
# 构建 Hikari-Cursor.app(图形界面)和 mousecur(命令行),产物在 dist/
set -e
cd "$(dirname "$0")"

swift build -c release

APP=dist/Hikari-Cursor.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/CursorSwapApp "$APP/Contents/MacOS/Hikari-Cursor"
cp .build/release/mousecur "$APP/Contents/Resources/mousecur"
cp .build/release/mousecur dist/mousecur
cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.hikaricursor.app</string>
    <key>CFBundleName</key><string>Hikari-Cursor</string>
    <key>CFBundleDisplayName</key><string>Hikari-Cursor 鼠标指针替换</string>
    <key>CFBundleExecutable</key><string>Hikari-Cursor</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>本地工具,使用 SkyLight 私有接口全局替换系统光标。</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - "$APP/Contents/Resources/mousecur" 2>/dev/null || true
codesign --force --sign - "$APP" 2>/dev/null || true
codesign --force --sign - dist/mousecur 2>/dev/null || true
touch "$APP"

echo "完成:"
echo "  $(pwd)/dist/Hikari-Cursor.app   (双击运行)"
echo "  $(pwd)/dist/mousecur            (命令行)"
