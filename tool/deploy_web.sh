#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   PUBLICADOR DA PWA - MINHAS CIFRAS WEB"
echo "=========================================="

echo ""
echo "🌐 [1/5] Compilando Web PWA (release)..."
flutter build web --release --base-href "/minhascifras-web/"

echo ""
echo "🧹 [2/5] Limpando arquivos residuais e conflitantes..."
find build/web -type f \( -name "* 2.*" -o -name "* 3.*" -o -name "* 4.*" -o -name ".DS_Store" \) -delete

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "web")
BUILD_TIMESTAMP=$(date +%s)
BUILD_VERSION="${GIT_BRANCH}-${BUILD_TIMESTAMP}"
CACHE_NAME="minhas-cifras-offline-${BUILD_VERSION}"

echo ""
echo "🏷️ [3/5] Gerando versão única de cache offline: $CACHE_NAME"
echo "📦 Coletando todos os assets reais de build/web para precache garantido..."

# Varre todos os arquivos estáticos compilados em build/web e monta a lista JSON de CORE_ASSETS
ASSETS_JSON=$(python3 -c "
import os, json
root = 'build/web'
ignore = {'.git', '.last_build_id', 'sw.js', 'flutter_service_worker.js', '.DS_Store', '404.html'}
assets = [
    './',
    'index.html',
    '/minhascifras-web/',
    '/minhascifras-web',
    '/minhascifras-web/index.html'
]
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in ignore and not d.startswith('.')]
    for f in filenames:
        if f in ignore or f.endswith('.symbols') or ' 2.' in f or ' 3.' in f or ' 4.' in f:
            continue
        rel = os.path.relpath(os.path.join(dirpath, f), root).replace('\\\\', '/')
        if rel not in assets:
            assets.append(rel)
print(json.dumps(assets, indent=2))
")

echo "⚙️ [4/5] Configurando Service Worker, Precache e CanvasKit local..."

# 1. Cria o sw.js com o CACHE_NAME e CORE_ASSETS dinâmicos
python3 -c "
import json
with open('web/sw.js', 'r') as f:
    content = f.read()

content = content.replace('__CACHE_NAME__', '$CACHE_NAME')
content = content.replace('__CORE_ASSETS__', '''$ASSETS_JSON''')

with open('build/web/sw.js', 'w') as f:
    f.write(content)
"

# 2. Copia sw.js para flutter_service_worker.js para retrocompatibilidade
cp build/web/sw.js build/web/flutter_service_worker.js

# 3. Atualiza index.html com a versão única de build
sed -i '' "s/__BUILD_VERSION__/$BUILD_VERSION/g" build/web/index.html
sed -i '' "s/sw\.js?v=[^'\"]*/sw.js?v=$BUILD_VERSION/g" build/web/index.html

# 4. Cria 404.html como cópia de index.html para o GitHub Pages servir todas as rotas
cp build/web/index.html build/web/404.html

# 5. Ajusta flutter_bootstrap.js:
# - Desabilita o service worker legado do Flutter para não competir com nosso sw.js
# - Força o CanvasKit a carregar os binários da pasta local canvaskit/ (garante offline sem gstatic.com)
# - Fornece fallback resiliente de WebAssembly para WebKit / iOS Safari caso compileStreaming falhe
# - Oculta a tela de loading ao inicializar o Flutter
python3 -c "
import re

with open('build/web/flutter_bootstrap.js', 'r') as f:
    code = f.read()

# Desativa o worker concorrente legado do Flutter e direciona CanvasKit para pasta local
code = re.sub(r'serviceWorkerSettings\s*:\s*\{', 'serviceWorkerSettings: null, config: {canvasKitBaseUrl: \"canvaskit/\"}, _old: {', code)
code = re.sub(r'\"serviceWorkerVersion\"\s*:', '\"_disabled_sw\":', code)

# Resiliência WebAssembly para Safari iOS: fallback se compileStreaming falhar
old_k = 'var k=i=>{let e=WebAssembly.compileStreaming(fetch(i));return(n,t)=>((async()=>{let r=await e,a=await WebAssembly.instantiate(r,n);t(a,r)})(),{})};'
new_k = 'var k=i=>{let e=(async()=>{try{if(typeof WebAssembly.compileStreaming===\"function\"){return await WebAssembly.compileStreaming(fetch(i));}}catch(_){}let r=await fetch(i);let b=await r.arrayBuffer();return await WebAssembly.compile(b);})();return(n,t)=>((async()=>{let r=await e,a=await WebAssembly.instantiate(r,n);t(a,r)})(),{})};'
if old_k in code:
    code = code.replace(old_k, new_k)

# Garante que a tela de loading inicial seja removida assim que o Flutter renderizar
old_run = 'l.initializeEngine(t).then(u=>u.runApp())'
new_run = 'l.initializeEngine(t).then(u=>u.runApp()).then(()=>{try{var loader=document.getElementById(\"loading-screen\");if(loader){loader.style.opacity=\"0\";setTimeout(function(){loader.remove();},400);}}catch(e){}})'
if old_run in code:
    code = code.replace(old_run, new_run)

with open('build/web/flutter_bootstrap.js', 'w') as f:
    f.write(code)
"

echo ""
echo "🔍 Validando integridade dos arquivos compilados (Sanity Check)..."
if [ ! -s build/web/index.html ]; then
  echo "❌ ERRO: build/web/index.html está vazio ou ausente!"
  exit 1
fi
if [ ! -s build/web/main.dart.js ]; then
  echo "❌ ERRO: build/web/main.dart.js está vazio ou ausente!"
  exit 1
fi
if [ ! -s build/web/sw.js ]; then
  echo "❌ ERRO: build/web/sw.js está vazio ou ausente!"
  exit 1
fi
if [ ! -s build/web/canvaskit/canvaskit.wasm ]; then
  echo "❌ ERRO: build/web/canvaskit/canvaskit.wasm não foi encontrado!"
  exit 1
fi
echo "✅ Todos os arquivos essenciais estão íntegros e validados!"

echo ""
echo "🚀 [5/5] Enviando para o repositório público minhascifras-web..."

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
git commit -m "deploy(pwa): versão $BUILD_VERSION com precache offline garantido" || echo "Nenhuma alteração pendente"

# Tentativa de push com retry automático em caso de oscilação de rede
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
echo "Versão: $BUILD_VERSION"
echo "Acesse em: https://nogueiraronald.github.io/minhascifras-web/"
echo "Modo 100% offline garantido com precache completo de todos os assets."
echo "=========================================="
