import 'package:flutter/material.dart';

import '../dados/controlador_conta.dart';
import '../servicos/servico_sincronizacao.dart';

/// Diálogo modal obrigatório exibido quando o usuário abre ou escaneia
/// um repertório protegido por senha no novo aparelho.
class DialogoDesbloqueioConta extends StatefulWidget {
  const DialogoDesbloqueioConta({
    super.key,
    required this.account,
    required this.sync,
  });

  final AccountController account;
  final SyncService sync;

  static Future<bool?> show(
    BuildContext context,
    AccountController account,
    SyncService sync,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoDesbloqueioConta(
        account: account,
        sync: sync,
      ),
    );
  }

  @override
  State<DialogoDesbloqueioConta> createState() =>
      _DialogoDesbloqueioContaState();
}

class _DialogoDesbloqueioContaState extends State<DialogoDesbloqueioConta> {
  final _passCtrl = TextEditingController();
  bool _obscureText = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) {
      setState(() => _error = 'Por favor, digite a senha.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await widget.account.unlockPendingSync(pass);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _loading = false;
        _error = 'Senha incorreta! Verifique a senha definida no aparelho principal.';
      });
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
    await widget.sync.sync();

    messenger?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Repertório desbloqueado e sincronizado com sucesso!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cancel() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    widget.account.cancelPendingSync();
    if (Navigator.canPop(context)) {
      Navigator.pop(context, false);
    }
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Conexão cancelada. Permanecendo no repertório local.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final code = widget.account.pendingSyncCode ??
        widget.account.syncCode ??
        'MC-000000';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Repertório Protegido por Senha',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.purple[200] : Colors.purple[800],
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Este repertório foi compartilhado com proteção por senha. Para baixar as cifras e setlists para este aparelho, informe a senha cadastrada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passCtrl,
                obscureText: _obscureText,
                autofocus: true,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'Senha do Repertório',
                  hintText: 'Digite a senha',
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _unlock(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _loading ? null : _cancel,
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _unlock,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Desbloquear e Baixar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
