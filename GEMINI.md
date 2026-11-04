# Diretrizes do Projeto Minhas Cifras

## Rotina Obrigatória de Atualização e Deploy

Sempre que concluir alterações solicitadas pelo usuário:

1. **Bateria de Testes Pré-Deploy Obrigatória (PWA e Desktop)**:
   - Executar `flutter analyze` e garantir 0 erros/alertas.
   - Executar a suite completa de testes de acesso e execução antes de qualquer deploy:
     - PWA em Micros/Computadores (Desktop 1920x1080 e 1366x768).
     - iPhones (Safari/PWA mobile: viewports 375x667, 390x844, 430x932).
     - Androids (Chrome/PWA mobile: viewports 360x800, 412x915).
     - macOS Desktop (resoluções 1280x800 e 1440x900).
   - Executar `flutter test` e assegurar 100% de aprovação de todos os testes.
   - **REGRA INEGOCIÁVEL**: Só avançar para o deploy se todos os testes forem aprovados. Se houver falha, corrigir a causa raiz antes de prosseguir.

2. **Criação de Branch Incremental**:
   - Verificar a última versão de branch existente (ex: `v23`, `v24`, etc.).
   - Criar e mudar para a próxima branch incremental (ex: `git checkout -b v24`).
   - Adicionar e commitar todas as alterações com mensagem descritiva:
     ```bash
     git add -A && git commit -m "feat(vX): descrição das melhorias"
     ```

3. **Mesclagem na Main**:
   - Mudar para a `main` e mesclar a nova branch:
     ```bash
     git checkout main && git merge vX
     ```

4. **Sincronização Remota**:
   - Enviar a nova branch e a `main` para o repositório:
     ```bash
     git push -u origin vX && git push origin main
     ```

5. **Deploy da Versão Web (PWA)**:
   - Executar o script oficial de deploy:
     ```bash
     ./tool/deploy_web.sh
     ```
   - Isso compila a versão Web release com base-href `/minhascifras-web/`, assegura o Service Worker offline (`sw.js`) e atualiza o repositório público `minhascifras-web` no GitHub Pages.
