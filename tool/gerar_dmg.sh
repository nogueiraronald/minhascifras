#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   GERADOR DE DMG (macOS) - MINHAS CIFRAS"
echo "=========================================="

echo ""
echo "📦 [1/4] Compilando macOS Release..."
flutter build macos --release

echo ""
echo "🎨 [2/4] Gerando ícone oficial (.icns)..."
mkdir -p build/AppIcon.iconset
ICON_SRC="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"

if [ -f "$ICON_SRC" ]; then
  sips -z 16 16     "$ICON_SRC" --out build/AppIcon.iconset/icon_16x16.png >/dev/null 2>&1
  sips -z 32 32     "$ICON_SRC" --out build/AppIcon.iconset/icon_16x16@2x.png >/dev/null 2>&1
  sips -z 32 32     "$ICON_SRC" --out build/AppIcon.iconset/icon_32x32.png >/dev/null 2>&1
  sips -z 64 64     "$ICON_SRC" --out build/AppIcon.iconset/icon_32x32@2x.png >/dev/null 2>&1
  sips -z 128 128   "$ICON_SRC" --out build/AppIcon.iconset/icon_128x128.png >/dev/null 2>&1
  sips -z 256 256   "$ICON_SRC" --out build/AppIcon.iconset/icon_128x128@2x.png >/dev/null 2>&1
  sips -z 256 256   "$ICON_SRC" --out build/AppIcon.iconset/icon_256x256.png >/dev/null 2>&1
  sips -z 512 512   "$ICON_SRC" --out build/AppIcon.iconset/icon_256x256@2x.png >/dev/null 2>&1
  sips -z 512 512   "$ICON_SRC" --out build/AppIcon.iconset/icon_512x512.png >/dev/null 2>&1
  sips -z 1024 1024 "$ICON_SRC" --out build/AppIcon.iconset/icon_512x512@2x.png >/dev/null 2>&1
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns >/dev/null 2>&1 || true
  rm -rf build/AppIcon.iconset
fi

echo ""
echo "📀 [3/4] Montando staging e gerando arquivo DMG..."
rm -rf build/dmg_staging
mkdir -p build/dmg_staging

# Copia o binário macOS compilado
APP_PATH=$(find build/macos/Build/Products/Release -maxdepth 1 -name "*.app" | head -n 1)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "❌ Erro: Nenhum app encontrado em build/macos/Build/Products/Release/"
  exit 1
fi

cp -R "$APP_PATH" build/dmg_staging/
ln -s /Applications build/dmg_staging/Applications

if [ -f build/AppIcon.icns ]; then
  cp build/AppIcon.icns build/dmg_staging/.VolumeIcon.icns
  SetFile -c icnC build/dmg_staging/.VolumeIcon.icns 2>/dev/null || true
  SetFile -a C build/dmg_staging 2>/dev/null || true
fi

rm -f build/MinhasCifras.dmg
hdiutil create -volname "Minhas Cifras" -srcfolder build/dmg_staging -ov -format UDZO build/MinhasCifras.dmg

echo ""
echo "✨ [4/4] Copiando para ~/Downloads e aplicando ícone no Finder..."
cp build/MinhasCifras.dmg "$HOME/Downloads/MinhasCifras.dmg" 2>/dev/null || true

if [ -f "$ICON_SRC" ]; then
  swift -e "
  import Cocoa
  if let icon = NSImage(contentsOfFile: \"$ICON_SRC\") {
    NSWorkspace.shared.setIcon(icon, forFile: \"build/MinhasCifras.dmg\", options: [])
    let dlPath = NSString(string: \"~/Downloads/MinhasCifras.dmg\").expandingTildeInPath
    if FileManager.default.fileExists(atPath: dlPath) {
      NSWorkspace.shared.setIcon(icon, forFile: dlPath, options: [])
    }
  }
  " 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "🎉 ARQUIVO DMG GERADO COM SUCESSO!"
echo "=========================================="
echo "📁 Local 1: build/MinhasCifras.dmg"
echo "📁 Local 2: $HOME/Downloads/MinhasCifras.dmg"
echo "=========================================="
