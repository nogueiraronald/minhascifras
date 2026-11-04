#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   PUBLICADOR DA PWA - MINHAS CIFRAS WEB"
echo "=========================================="

echo ""
echo "🌐 [1/2] Compilando Web PWA com base-href..."
flutter build web --release --base-href "/minhascifras-web/"

# Garante o Service Worker offline em sw.js e substitui o dummy do Flutter
cp web/sw.js build/web/sw.js
cp web/sw.js build/web/flutter_service_worker.js

echo ""
echo "🚀 [2/2] Enviando para o repositório público minhascifras-web..."

cd build/web
if [ ! -d ".git" ] || [ "$(git remote get-url origin 2>/dev/null)" != "git@github.com:nogueiraronald/minhascifras-web.git" ]; then
  echo "Configurando repositório minhascifras-web em build/web..."
  rm -rf .git
  git init -b main
  git remote add origin git@github.com:nogueiraronald/minhascifras-web.git
  git fetch origin main || true
  git reset --soft origin/main 2>/dev/null || true
fi

git config core.sshCommand "ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes" 2>/dev/null || true
git add -A
git commit -m "Atualização da PWA: $(date '+%d/%m/%Y %H:%M')" || echo "Nenhuma alteração pendente"

# Tentativa de push com retry automático em caso de rate-limit do GitHub
max_attempts=3
attempt=1
until git push origin main; do
  if [ $attempt -ge $max_attempts ]; then
    echo "❌ Falha ao enviar para o GitHub após $attempt tentativas."
    exit 1
  fi
  echo "Aguardando 2 segundos para tentar novamente (tentativa $attempt/$max_attempts)..."
  sleep 2
  attempt=$((attempt+1))
done

echo ""
echo "=========================================="
echo "🎉 PWA PUBLICADA COM SUCESSO!"
echo "Acesse em: https://nogueiraronald.github.io/minhascifras-web/"
echo "=========================================="
