import 'package:flutter/material.dart';

import '../componentes/botao_conta.dart';
import '../componentes/botao_sincronizacao.dart';
import '../componentes/dialogo_desbloqueio_conta.dart';
import '../componentes/estilo_app.dart';
import '../componentes/logo_aplicativo.dart';
import '../dados/biblioteca_acordes.dart';
import '../dados/controlador_conta.dart';
import '../dados/controlador_tema.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../dados/repositorio_temas.dart';
import '../servicos/servico_comunidade.dart';
import '../servicos/servico_sincronizacao.dart';
import 'tela_comunidade.dart';
import 'tela_principal.dart';

/// Página Inicial do aplicativo MinhasCifras:
/// - Cabeçalho no topo com os dados do app (logo, nome, slogan, status de sincronização e conta).
/// - Dois cards elegantes com a mesma identidade visual: "Minhas Cifras" e "Comunidade".
class TelaInicial extends StatefulWidget {
  const TelaInicial({
    super.key,
    required this.repository,
    required this.chords,
    required this.account,
    required this.sync,
    required this.setlists,
    required this.musicThemes,
    this.theme,
    this.communityService,
  });

  final SongRepository repository;
  final ChordLibrary chords;
  final AccountController account;
  final SyncService sync;
  final SetlistRepository setlists;
  final ThemeRepository musicThemes;
  final ThemeController? theme;
  final CommunityService? communityService;

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  bool _isUnlockDialogShowing = false;

  @override
  void initState() {
    super.initState();
    widget.account.addListener(_checkAccountLock);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccountLock();
    });
  }

  @override
  void dispose() {
    widget.account.removeListener(_checkAccountLock);
    super.dispose();
  }

  void _checkAccountLock() {
    if (widget.account.isLocked && mounted && !_isUnlockDialogShowing) {
      _isUnlockDialogShowing = true;
      DialogoDesbloqueioConta.show(context, widget.account, widget.sync)
          .then((_) {
        _isUnlockDialogShowing = false;
      });
    }
  }

  void _openMinhasCifras() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          repository: widget.repository,
          chords: widget.chords,
          account: widget.account,
          sync: widget.sync,
          setlists: widget.setlists,
          musicThemes: widget.musicThemes,
          theme: widget.theme,
          communityService: widget.communityService,
        ),
      ),
    );
  }

  void _openComunidade() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TelaComunidade(
          repository: widget.repository,
          chords: widget.chords,
          account: widget.account,
          sync: widget.sync,
          setlists: widget.setlists,
          theme: widget.theme,
          communityService: widget.communityService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 760;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.repository,
        widget.setlists,
        widget.account,
      ]),
      builder: (context, _) {
        final songCount = widget.repository.songs.length;
        final setlistCount = widget.setlists.setlists.length;

        final minhasCifrasHighlight = songCount > 0
            ? 'Seu acervo conta atualmente com $songCount cifra(s) e $setlistCount lista(s) prontas para o seu momento musical.'
            : 'Monte seu repertório personalizado, crie listas para suas apresentações e tenha suas músicas favoritas sempre à mão.';

        const comunidadeHighlight =
            'Um espaço colaborativo onde músicos compartilham seus arranjos, descobrem novas canções e enriquecem seus repertórios.';

        return Scaffold(
          key: const ValueKey('home_screen_scaffold'),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho no topo com os dados do app (logo, nome, etc.)
                _buildHeader(context, isDark, isMobile),

                // Corpo com os dois cards elegantes: Minhas Cifras e Comunidade
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 32,
                        vertical: isMobile ? 16 : 28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1020),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Saudação e descrição institucional do app
                            Text(
                              'Bem-vindo ao MinhasCifras',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 22 : 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Escolha como deseja viver a sua música hoje: no seu repertório pessoal ou conectado à comunidade.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 15,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: isMobile ? 20 : 32),

                            if (isMobile) ...[
                              _buildFeatureCard(
                                cardKey: const ValueKey('card_minhas_cifras'),
                                isDark: isDark,
                                icon: Icons.library_music_rounded,
                                title: 'Minhas Cifras',
                                subtitle:
                                    'O seu palco particular. Organize suas músicas, prepare listas de repertório, ajuste tons e toque com fluidez em qualquer lugar.',
                                highlightIcon: Icons.music_note_rounded,
                                highlightText: minhasCifrasHighlight,
                                buttonLabel: 'Acessar Minhas Cifras',
                                buttonIcon: Icons.arrow_forward_rounded,
                                onTap: _openMinhasCifras,
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureCard(
                                cardKey: const ValueKey('card_comunidade'),
                                isDark: isDark,
                                icon: Icons.groups_rounded,
                                title: 'Comunidade',
                                subtitle:
                                    'A música ganha mais força quando é compartilhada. Divulgue suas cifras favoritas e inspire-se com o repertório de outros músicos.',
                                highlightIcon: Icons.auto_awesome_rounded,
                                highlightText: comunidadeHighlight,
                                buttonLabel: 'Explorar Comunidade',
                                buttonIcon: Icons.public_rounded,
                                onTap: _openComunidade,
                              ),
                            ] else
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildFeatureCard(
                                        cardKey: const ValueKey(
                                            'card_minhas_cifras'),
                                        isDark: isDark,
                                        icon: Icons.library_music_rounded,
                                        title: 'Minhas Cifras',
                                        subtitle:
                                            'O seu palco particular. Organize suas músicas, prepare listas de repertório, ajuste tons e toque com fluidez em qualquer lugar.',
                                        highlightIcon: Icons.music_note_rounded,
                                        highlightText: minhasCifrasHighlight,
                                        buttonLabel: 'Acessar Minhas Cifras',
                                        buttonIcon: Icons.arrow_forward_rounded,
                                        onTap: _openMinhasCifras,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildFeatureCard(
                                        cardKey:
                                            const ValueKey('card_comunidade'),
                                        isDark: isDark,
                                        icon: Icons.groups_rounded,
                                        title: 'Comunidade',
                                        subtitle:
                                            'A música ganha mais força quando é compartilhada. Divulgue suas cifras favoritas e inspire-se com o repertório de outros músicos.',
                                        highlightIcon:
                                            Icons.auto_awesome_rounded,
                                        highlightText: comunidadeHighlight,
                                        buttonLabel: 'Explorar Comunidade',
                                        buttonIcon: Icons.public_rounded,
                                        onTap: _openComunidade,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Cabeçalho superior com logo, nome, slogan e controles da conta
  Widget _buildHeader(BuildContext context, bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 28,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.75)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppCores.roxo.withValues(alpha: 0.18),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppCores.roxo.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: AppLogo(iconSize: 24),
          ),
          if (!isMobile && widget.account.hasNickname) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppCores.roxo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppCores.roxo.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded,
                      size: 14, color: AppCores.roxo),
                  const SizedBox(width: 4),
                  Text(
                    '@${widget.account.userNickname}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppCores.roxo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.theme != null)
            IconButton(
              tooltip: widget.theme!.isDark(context)
                  ? 'Mudar para Modo Claro'
                  : 'Mudar para Modo Escuro',
              icon: Icon(
                widget.theme!.isDark(context)
                    ? Icons.light_mode
                    : Icons.dark_mode_outlined,
                size: 20,
              ),
              onPressed: () => widget.theme!.toggle(context),
            ),
          SyncButton(sync: widget.sync, account: widget.account),
          AccountButton(
            account: widget.account,
            songs: widget.repository,
            setlists: widget.setlists,
            sync: widget.sync,
            compact: isMobile,
          ),
        ],
      ),
    );
  }

  /// Card elegante com a identidade visual do MinhasCifras e divulgação inspiradora
  Widget _buildFeatureCard({
    required Key cardKey,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required IconData highlightIcon,
    required String highlightText,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onTap,
  }) {
    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppCores.roxo.withValues(alpha: 0.22),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppCores.roxo.withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Barra superior no gradiente da marca
                Container(
                  height: 5,
                  decoration: const BoxDecoration(
                    gradient: AppCores.gradienteLogo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BadgeIconeGradiente(
                            icon: icon,
                            size: 52,
                            iconSize: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppCores.gradienteTranslucido(isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppCores.roxo.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              highlightIcon,
                              size: 18,
                              color: AppCores.roxo,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                highlightText,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: BotaoGradiente(
                          onPressed: onTap,
                          icon: buttonIcon,
                          label: buttonLabel,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
