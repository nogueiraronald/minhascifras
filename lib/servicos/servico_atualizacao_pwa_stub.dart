import 'package:flutter/material.dart';

/// Implementação para Desktop e plataformas nativas onde updates são feitos via binário/DMG.
Future<void> verificarAtualizacao(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('✓ O Minhas Cifras Desktop está atualizado.'),
      duration: Duration(seconds: 3),
    ),
  );
}

Future<void> verificarEForcarAtualizacaoAoIniciar() async {
  // Desktop e plataformas nativas não requerem reload de Service Worker
}
