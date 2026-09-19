#!/bin/bash
set -e

PROJECT_DIR="/Volumes/Izumi & Mac/Work/Github/Quanqian"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_ROOT="/Volumes/Izumi & Mac/Work/开发/Quanqian"
VERSION_DIR="$OUTPUT_ROOT/v1.0.0"

cd "$PROJECT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$VERSION_DIR"

echo "===> 1. 编译 C 语言图像处理扩展..."
for cfile in Compositor/Rendering/*.c; do
  bname=$(basename "$cfile" .c)
  if [ ! -f "$BUILD_DIR/$bname.o" ] || [ "$cfile" -nt "$BUILD_DIR/$bname.o" ]; then
    clang -O3 -c "$cfile" -o "$BUILD_DIR/$bname.o"
  fi
done

echo "===> 2. 检查高清 App 图标 (icns)..."
if [ ! -f "$BUILD_DIR/AppIcon.icns" ]; then
  ICONSET_DIR="$BUILD_DIR/Quanqian.iconset"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  SRC="Compositor/Assets.xcassets/AppIcon.appiconset"
  cp "$SRC/app-icon-16.png" "$ICONSET_DIR/icon_16x16.png"
  cp "$SRC/app-icon-32.png" "$ICONSET_DIR/icon_16x16@2x.png"
  cp "$SRC/app-icon-32.png" "$ICONSET_DIR/icon_32x32.png"
  cp "$SRC/app-icon-64.png" "$ICONSET_DIR/icon_32x32@2x.png"
  cp "$SRC/app-icon-128.png" "$ICONSET_DIR/icon_128x128.png"
  cp "$SRC/app-icon-256.png" "$ICONSET_DIR/icon_128x128@2x.png"
  cp "$SRC/app-icon-256.png" "$ICONSET_DIR/icon_256x256.png"
  cp "$SRC/app-icon-512.png" "$ICONSET_DIR/icon_256x256@2x.png"
  cp "$SRC/app-icon-512.png" "$ICONSET_DIR/icon_512x512.png"
  cp "$SRC/app-icon-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/AppIcon.icns"
fi

echo "===> 3. 编译 Swift 源码与链接二进制..."
find Compositor -name "*.swift" > "$BUILD_DIR/sources.txt"
swiftc -O -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -import-objc-header Compositor/Compositor-Bridging-Header.h \
  -I Compositor \
  "$BUILD_DIR"/*.o \
  @"$BUILD_DIR/sources.txt" \
  -o "$BUILD_DIR/Quanqian_bin"

echo "===> 4. 组装 Quanqian.app Bundle..."
APP_BUNDLE="$BUILD_DIR/Quanqian.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/Quanqian_bin" "$APP_BUNDLE/Contents/MacOS/Quanqian"
chmod +x "$APP_BUNDLE/Contents/MacOS/Quanqian"
cp "$BUILD_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

cat << 'PLIST' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleDisplayName</key>
    <string>泉嵌 (Quanqian)</string>
    <key>CFBundleExecutable</key>
    <string>Quanqian</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.wonderassembly.quanqian</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Quanqian</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.4</string>
    <key>CFBundleVersion</key>
    <string>5</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array><dict>
        <key>CFBundleTypeName</key><string>Images</string>
        <key>CFBundleTypeRole</key><string>Viewer</string>
        <key>LSHandlerRank</key><string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array><string>public.jpeg</string><string>public.png</string><string>public.heic</string><string>public.tiff</string></array>
    </dict><dict>
        <key>CFBundleTypeName</key><string>Compositor Project</string>
        <key>CFBundleTypeRole</key><string>Editor</string>
        <key>LSHandlerRank</key><string>Owner</string>
        <key>LSTypeIsPackage</key><true/>
        <key>LSItemContentTypes</key><array><string>com.compositor.project</string></array>
    </dict></array>
    <key>UTExportedTypeDeclarations</key>
    <array><dict>
        <key>UTTypeIdentifier</key><string>com.compositor.layer-row</string>
        <key>UTTypeDescription</key><string>Compositor Layer</string>
        <key>UTTypeConformsTo</key><array><string>public.data</string></array>
    </dict><dict>
        <key>UTTypeIdentifier</key><string>com.compositor.project</string>
        <key>UTTypeDescription</key><string>Compositor Project</string>
        <key>UTTypeConformsTo</key><array><string>com.apple.package</string></array>
        <key>UTTypeTagSpecification</key><dict>
            <key>public.filename-extension</key><array><string>comp</string></array>
        </dict>
    </dict></array>
</dict></plist>
PLIST

echo "===> 5. 对应用包签名 (Ad-Hoc Codesign)..."
codesign --force --deep --sign - --entitlements Config/Compositor.entitlements "$APP_BUNDLE"

echo "===> 6. 复制到发布目录并打包..."
rm -rf "$VERSION_DIR/Quanqian.app"
cp -R "$APP_BUNDLE" "$VERSION_DIR/Quanqian.app"

rm -rf "$OUTPUT_ROOT/Quanqian.app"
cp -R "$APP_BUNDLE" "$OUTPUT_ROOT/Quanqian.app"

cd "$VERSION_DIR"
rm -f "Quanqian-v1.0.0-macOS.zip"
zip -qry "Quanqian-v1.0.0-macOS.zip" "Quanqian.app"

echo "===> 全部打包任务圆满完成！发布包已更新至 $VERSION_DIR"
