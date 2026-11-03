#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   GERADOR DE INSTALADORES - MINHAS CIFRAS"
echo "=========================================="

# 1. macOS (DMG)
echo ""
echo "📦 [1/3] Compilando macOS Release..."
flutter build macos --release
echo "📀 Gerando arquivo DMG com ícone oficial..."
rm -rf build/dmg_staging
mkdir -p build/dmg_staging
cp -R build/macos/Build/Products/Release/MinhasCifras.app build/dmg_staging/
ln -s /Applications build/dmg_staging/Applications
if [ -f build/AppIcon.icns ]; then
  cp build/AppIcon.icns build/dmg_staging/.VolumeIcon.icns
  SetFile -c icnC build/dmg_staging/.VolumeIcon.icns 2>/dev/null || true
  SetFile -a C build/dmg_staging 2>/dev/null || true
fi
rm -f build/MinhasCifras.dmg
hdiutil create -volname "Minhas Cifras" -srcfolder build/dmg_staging -ov -format UDZO build/MinhasCifras.dmg
cp build/MinhasCifras.dmg "$HOME/Downloads/MinhasCifras.dmg" 2>/dev/null || true
echo "✅ DMG criado em: build/MinhasCifras.dmg (e copiado para ~/Downloads/MinhasCifras.dmg)"

# 2. Web (PWA 100% Offline)
echo ""
echo "🌐 [2/3] Compilando Web PWA (Offline)..."
flutter build web --release
echo "✅ Web PWA criada em: build/web (pronta para hospedar)"

# 3. Android (APK)
echo ""
echo "📱 [3/3] Compilando Android APK..."
flutter build apk --release
echo "✅ APK criado em: build/app/outputs/flutter-apk/app-release.apk"

echo ""
echo "=========================================="
echo "🎉 TODOS OS PACOTES FORAM GERADOS COM SUCESSO!"
echo "=========================================="
echo "1. Mac:     build/MinhasCifras.dmg"
echo "2. Android: build/app/outputs/flutter-apk/app-release.apk"
echo "3. Web:     build/web"
echo "=========================================="
