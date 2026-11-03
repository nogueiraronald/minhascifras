#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   PUBLICADOR DA PWA - MINHAS CIFRAS WEB"
echo "=========================================="

echo ""
echo "🌐 [1/2] Compilando Web PWA com base-href..."
flutter build web --release --base-href "/minhascifras-web/"

echo ""
echo "🚀 [2/2] Enviando para o repositório público minhascifras-web..."
cd build/web
git add -A
git commit -m "Atualização da PWA: $(date '+%d/%m/%Y %H:%M')" || echo "Nenhuma alteração pendente"
git push origin main

echo ""
echo "=========================================="
echo "🎉 PWA PUBLICADA COM SUCESSO!"
echo "Acesse em: https://nogueiraronald.github.io/minhascifras-web/"
echo "=========================================="
