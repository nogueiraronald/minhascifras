import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart'
    show BuildContext, Colors, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../dados/controlador_conta.dart';
import 'salvador_arquivo.dart';


/// Serviço responsável por gerar e baixar o Cartão Oficial de Recuperação em PDF
/// com design premium, logo oficial em alta resolução, QR Code vetorial e dados
/// completos para restaurar a conta caso o usuário não tenha acesso ao aparelho antigo.
class RecoveryPdfService {
  RecoveryPdfService._();

  static Future<void> generateAndDownload({
    required AccountController account,
    required BuildContext context,
    int? songCount,
    int? setlistCount,
  }) async {
    final code = account.syncCode ?? 'MC-000000';
    final syncUrl = account.syncUrl;
    final isProtected = account.isPasswordProtected;

    try {
      // Carrega o logotipo oficial do app dos assets se disponível
      pw.MemoryImage? logoImage;
      try {
        final byteData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      final doc = pw.Document(
        title: 'Cartao_Recuperacao_Minhas_Cifras_$code',
        author: 'Minhas Cifras',
      );

      final primaryColor = PdfColor.fromHex('#4F46E5');
      final accentColor = PdfColor.fromHex('#7C3AED');
      final darkColor = PdfColor.fromHex('#0F172A');
      final lightBgColor = PdfColor.fromHex('#F8FAFC');
      final borderColor = PdfColor.fromHex('#CBD5E1');

      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} às ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: borderColor, width: 1.2),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. CABEÇALHO MODERNO COM LOGO OFICIAL
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    decoration: pw.BoxDecoration(
                      color: darkColor,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(14),
                        topRight: pw.Radius.circular(14),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            if (logoImage != null)
                              pw.ClipRRect(
                                horizontalRadius: 10,
                                verticalRadius: 10,
                                child: pw.Image(
                                  logoImage,
                                  width: 44,
                                  height: 44,
                                ),
                              )
                            else
                              pw.Container(
                                width: 44,
                                height: 44,
                                decoration: pw.BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: pw.BorderRadius.circular(10),
                                ),
                                child: pw.Center(
                                  child: pw.Text(
                                    'MC',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            pw.SizedBox(width: 14),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Minhas Cifras',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                pw.Text(
                                  'Suas cifras, seu ritmo.',
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('#94A3B8'),
                                    fontSize: 10.5,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: accentColor,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            'CARTÃO DE RECUPERAÇÃO',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. CORPO DO CARTÃO DE RECUPERAÇÃO
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Bloco de Destaque da Chave Mestra
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: pw.BoxDecoration(
                            color: lightBgColor,
                            borderRadius: pw.BorderRadius.circular(12),
                            border: pw.Border.all(
                              color: primaryColor.shade(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'CHAVE MESTRA DE ACESSO DO REPERTÓRIO',
                                style: pw.TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#64748B'),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                code,
                                style: pw.TextStyle(
                                  fontSize: 34,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 5,
                                  color: primaryColor,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Esta chave identifica seu repertório de cifras na nuvem. Guarde este documento em local seguro.',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  color: PdfColor.fromHex('#475569'),
                                ),
                              ),
                              if (songCount != null || setlistCount != null) ...[
                                pw.SizedBox(height: 8),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: pw.BoxDecoration(
                                    color: primaryColor.shade(0.1),
                                    borderRadius: pw.BorderRadius.circular(12),
                                  ),
                                  child: pw.Text(
                                    'Conteúdo atual: ${songCount ?? 0} cifras salvas • ${setlistCount ?? 0} listas de repertório',
                                    style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 20),

                        // Bloco Central: QR Code + Instruções para Restaurar
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // QR Code nítido e emoldurado
                            pw.Column(
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(10),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(12),
                                    border: pw.Border.all(color: borderColor),
                                  ),
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: syncUrl,
                                    width: 130,
                                    height: 130,
                                    color: darkColor,
                                  ),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  'Aponte a câmera para parear',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColor.fromHex('#64748B'),
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(width: 20),
                            // Guia Passo a Passo: "Caso não tenha acesso ao antigo aparelho"
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Como restaurar em um novo aparelho:',
                                    style: pw.TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: darkColor,
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  _buildStep(
                                    number: '1',
                                    title: 'Abra o Minhas Cifras',
                                    description:
                                        'Em seu novo celular, tablet ou computador, abra o app ou acesse pelo navegador.',
                                    primaryColor: primaryColor,
                                  ),
                                  pw.SizedBox(height: 7),
                                  _buildStep(
                                    number: '2',
                                    title: 'Aponte a câmera ou digite',
                                    description:
                                        'Escaneie o QR Code ao lado ou clique no ícone de Nuvem e digite a chave $code.',
                                    primaryColor: primaryColor,
                                  ),
                                  pw.SizedBox(height: 7),
                                  _buildStep(
                                    number: '3',
                                    title: 'Informe a senha (se houver)',
                                    description:
                                        'Se você configurou uma senha de proteção, digite-a para liberar o acesso.',
                                    primaryColor: primaryColor,
                                  ),
                                  pw.SizedBox(height: 7),
                                  _buildStep(
                                    number: '4',
                                    title: 'Restauração Instantânea',
                                    description:
                                        'Todas as suas cifras, tons personalizados e listas serão restaurados na hora!',
                                    primaryColor: primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        pw.SizedBox(height: 18),

                        // Bloco de Segurança e Espaço para Anotação de Senha
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: isProtected
                                ? PdfColor.fromHex('#F0FDF4')
                                : lightBgColor,
                            borderRadius: pw.BorderRadius.circular(10),
                            border: pw.Border.all(
                              color: isProtected
                                  ? PdfColor.fromHex('#86EFAC')
                                  : borderColor,
                              width: 1.2,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                      color: isProtected
                                          ? PdfColor.fromHex('#166534')
                                          : PdfColor.fromHex('#475569'),
                                      borderRadius:
                                          pw.BorderRadius.circular(6),
                                    ),
                                    child: pw.Text(
                                      isProtected
                                          ? 'PROTEÇÃO POR SENHA ATIVA'
                                          : 'SEM SENHA CONFIGURADA',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 8.5,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Text(
                                      isProtected
                                          ? 'A senha cadastrada será exigida ao restaurar em qualquer novo aparelho.'
                                          : 'O acesso atual depende apenas da chave acima. Você pode criar uma senha no app.',
                                      style: pw.TextStyle(
                                        fontSize: 9,
                                        color: isProtected
                                          ? PdfColor.fromHex('#15803D')
                                          : PdfColor.fromHex('#64748B'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              // Campo de anotação de senha
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(6),
                                  border: pw.Border.all(
                                      color: borderColor,
                                      style: pw.BorderStyle.dashed),
                                ),
                                child: pw.Row(
                                  children: [
                                    pw.Text(
                                      'Anotação da Minha Senha:',
                                      style: pw.TextStyle(
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromHex('#334155'),
                                      ),
                                    ),
                                    pw.SizedBox(width: 8),
                                    pw.Expanded(
                                      child: pw.Text(
                                        '___________________________________________________________',
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColor.fromHex('#94A3B8'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 14),

                        // Link Direto Universal de Pareamento
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: borderColor),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Text(
                                'Link direto de pareamento:',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#64748B'),
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Expanded(
                                child: pw.UrlLink(
                                  destination: syncUrl,
                                  child: pw.Text(
                                    syncUrl,
                                    style: pw.TextStyle(
                                      fontSize: 8.5,
                                      color: primaryColor,
                                      fontWeight: pw.FontWeight.bold,
                                      decoration: pw.TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // 3. RODAPÉ OFICIAL COM METADADOS
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: borderColor)),
                      color: lightBgColor,
                      borderRadius: const pw.BorderRadius.only(
                        bottomLeft: pw.Radius.circular(14),
                        bottomRight: pw.Radius.circular(14),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Minhas Cifras • Aplicativo de Cifras e Repertório Musical',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#64748B'),
                          ),
                        ),
                        pw.Text(
                          'Gerado em: $dateStr',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#64748B'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      final fileName = 'minhas-cifras-recuperacao-$code.pdf';

      bool saved = false;
      final isDesktopOrWeb = kIsWeb ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux;

      if (isDesktopOrWeb) {
        try {
          saved = await saveFileToDevice(
            fileName,
            pdfBytes,
            mimeType: 'application/pdf',
          );
        } catch (_) {
          saved = false;
        }

        // Fallback seguro em Desktop/Web: preview nativo de impressão caso não tenha salvo
        if (!saved) {
          try {
            await Printing.layoutPdf(
              onLayout: (format) async => pdfBytes,
              name: fileName,
            );
            saved = true;
          } catch (_) {}
        }
      } else {
        // Plataformas Mobile (iOS e Android)
        try {
          await Printing.sharePdf(
            bytes: pdfBytes,
            filename: fileName,
          );
          saved = true;
        } catch (_) {
          try {
            await Printing.layoutPdf(
              onLayout: (format) async => pdfBytes,
              name: fileName,
            );
            saved = true;
          } catch (_) {}
        }
      }

      if (context.mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cartão de recuperação "$code" gerado com sucesso!'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  static pw.Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required PdfColor primaryColor,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 17,
          height: 17,
          decoration: pw.BoxDecoration(
            color: primaryColor,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              number,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '$title: ',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1E293B'),
                  ),
                ),
                pw.TextSpan(
                  text: description,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#475569'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
