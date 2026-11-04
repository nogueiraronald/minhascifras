# Diretrizes do Projeto Minhas Cifras

## Rotina Obrigatória de Atualização e Deploy

Sempre que concluir alterações solicitadas pelo usuário:

1. **Validação de Código e Testes**:
   - Executar `flutter analyze` e garantir 0 erros/alertas.
   - Executar `flutter test` e garantir que todos os testes passem.

2. **Criação de Branch Incremental**:
   - Verificar a última versão de branch existente (ex: `v9`, `v10`, etc.).
   - Criar e mudar para a próxima branch incremental (ex: `git checkout -b v11`).
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
