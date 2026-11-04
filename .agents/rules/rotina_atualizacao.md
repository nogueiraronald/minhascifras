---
description: Rotina obrigatória de versionamento em branch e deploy após conclusões de tarefas
---

# Rotina de Atualização e Deploy

Sempre que concluir alterações solicitadas pelo usuário:

1. Executar `flutter analyze` e `flutter test`.
2. Criar a próxima branch incremental (ex: `v10`, `v11`...).
3. Comitar as alterações e mesclar na `main`.
4. Enviar para o repositório remoto (`git push -u origin vX && git push origin main`).
5. Executar o deploy da PWA via `./tool/deploy_web.sh`.
