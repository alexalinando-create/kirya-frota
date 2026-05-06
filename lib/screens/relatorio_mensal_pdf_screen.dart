import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'relatorio_mensal_pdf.dart';

class RelatorioMensalPdfScreen extends StatefulWidget {
  const RelatorioMensalPdfScreen({super.key});

  @override
  State<RelatorioMensalPdfScreen> createState() =>
      _RelatorioMensalPdfScreenState();
}

class _RelatorioMensalPdfScreenState
    extends State<RelatorioMensalPdfScreen> {
  static const Color _background = Color(0xFF0A0E1A);
  static const Color _surface = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonPurple = Color(0xFFB388FF);
  static const Color _neonOrange = Color(0xFFFF6B35);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonPink = Color(0xFFFF4D6D);
  static const Color _neonGold = Color(0xFFE8C547);
  static const Color _textMain = Color(0xFFE8ECF4);
  static const Color _textMuted = Color(0xFF8A93A8);

  late int _mesSelecionado;
  late int _anoSelecionado;
  bool _gerando = false;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesSelecionado = agora.month;
    _anoSelecionado = agora.year;
  }

  List<int> _anosDisponiveis() {
    final agora = DateTime.now();
    return [agora.year - 2, agora.year - 1, agora.year, agora.year + 1];
  }

  Future<void> _visualizarPDF() async {
    setState(() => _gerando = true);
    try {
      final bytes = await RelatorioMensalPdf.gerar(
        mes: _mesSelecionado,
        ano: _anoSelecionado,
      );
      if (!mounted) return;
      setState(() => _gerando = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfPreviewScreen(
            pdfBytes: bytes,
            mes: _mesSelecionado,
            ano: _anoSelecionado,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gerando = false);
      _showError('Erro ao gerar PDF', e.toString());
    }
  }

  Future<void> _compartilharPDF() async {
    setState(() => _gerando = true);
    try {
      final bytes = await RelatorioMensalPdf.gerar(
        mes: _mesSelecionado,
        ano: _anoSelecionado,
      );
      final dir = await getTemporaryDirectory();
      final mesStr = _mesSelecionado.toString().padLeft(2, '0');
      final file = File('${dir.path}/relatorio_${_anoSelecionado}_$mesStr.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _gerando = false);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Relatório Mensal - ${_meses[_mesSelecionado - 1]}/$_anoSelecionado',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gerando = false);
      _showError('Erro ao compartilhar PDF', e.toString());
    }
  }

  Future<void> _imprimirPDF() async {
    setState(() => _gerando = true);
    try {
      final bytes = await RelatorioMensalPdf.gerar(
        mes: _mesSelecionado,
        ano: _anoSelecionado,
      );
      if (!mounted) return;
      setState(() => _gerando = false);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gerando = false);
      _showError('Erro ao imprimir PDF', e.toString());
    }
  }

  void _showError(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: _neonPink),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(color: _textMain)),
          ],
        ),
        content: Text(msg, style: const TextStyle(color: _textMuted)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _neonCyan),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _selectorBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required Color cor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.4), width: 1.2),
          boxShadow: [BoxShadow(color: cor.withOpacity(0.08), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cor, size: 16),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(
                  color: cor, fontSize: 10.5,
                  fontWeight: FontWeight.w800, letterSpacing: 0.8,
                )),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(
                  color: _textMain, fontSize: 17, fontWeight: FontWeight.w900,
                )),
                const Icon(Icons.expand_more, color: _textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selecionarMes() async {
    final mes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text('Escolha o mês', style: TextStyle(
                  color: _textMain, fontSize: 16, fontWeight: FontWeight.w900,
                )),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: List.generate(12, (i) {
                  final m = i + 1;
                  final selecionado = m == _mesSelecionado;
                  return InkWell(
                    onTap: () => Navigator.pop(context, m),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selecionado ? _neonCyan.withOpacity(0.2) : _background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selecionado ? _neonCyan : _neonCyan.withOpacity(0.2),
                          width: selecionado ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(_meses[i], style: TextStyle(
                          color: selecionado ? _neonCyan : _textMain,
                          fontWeight: selecionado ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 12,
                        )),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
    if (mes != null && mounted) setState(() => _mesSelecionado = mes);
  }

  Future<void> _selecionarAno() async {
    final ano = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text('Escolha o ano', style: TextStyle(
                  color: _textMain, fontSize: 16, fontWeight: FontWeight.w900,
                )),
              ),
              ..._anosDisponiveis().map((a) {
                final selecionado = a == _anoSelecionado;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, a),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selecionado ? _neonPurple.withOpacity(0.2) : _background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selecionado ? _neonPurple : _neonPurple.withOpacity(0.2),
                          width: selecionado ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selecionado ? Icons.check_circle : Icons.calendar_today_outlined,
                            color: selecionado ? _neonPurple : _textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(a.toString(), style: TextStyle(
                            color: selecionado ? _neonPurple : _textMain,
                            fontWeight: selecionado ? FontWeight.w900 : FontWeight.w700,
                            fontSize: 16,
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (ano != null && mounted) setState(() => _anoSelecionado = ano);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _neonPink,
          surface: _surface,
          onPrimary: _background,
          onSurface: _textMain,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _textMain,
          elevation: 0,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_neonPink, _neonGold],
            ).createShader(bounds),
            child: const Text(
              'RELATÓRIO PDF',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: _neonPink),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _neonPink.withOpacity(0.2),
                    _neonGold.withOpacity(0.08),
                  ],
                ),
                border: Border.all(color: _neonPink.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 50, width: 50,
                    decoration: BoxDecoration(
                      color: _neonPink.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: _neonPink, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Relatório Executivo', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: _textMain,
                        )),
                        SizedBox(height: 4),
                        Text('PDF profissional com análise mensal',
                          style: TextStyle(fontSize: 12, color: _textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== PERÍODO =====
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('PERÍODO', style: TextStyle(
                color: _neonCyan, fontSize: 12,
                fontWeight: FontWeight.w900, letterSpacing: 1.5,
              )),
            ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _selectorBox(
                    label: 'MÊS',
                    value: _meses[_mesSelecionado - 1],
                    icon: Icons.calendar_month,
                    cor: _neonCyan,
                    onTap: _selecionarMes,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _selectorBox(
                    label: 'ANO',
                    value: _anoSelecionado.toString(),
                    icon: Icons.event,
                    cor: _neonPurple,
                    onTap: _selecionarAno,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===== AÇÕES =====
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('AÇÕES', style: TextStyle(
                color: _neonCyan, fontSize: 12,
                fontWeight: FontWeight.w900, letterSpacing: 1.5,
              )),
            ),

            // Botão VISUALIZAR
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [_neonPink, _neonOrange]),
                boxShadow: [BoxShadow(color: _neonPink.withOpacity(0.35), blurRadius: 18)],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _gerando ? null : _visualizarPDF,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _gerando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _background))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.preview, color: _background),
                              SizedBox(width: 10),
                              Text('VISUALIZAR PDF', style: TextStyle(
                                color: _background, fontWeight: FontWeight.w900,
                                fontSize: 14, letterSpacing: 0.8,
                              )),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Botão COMPARTILHAR
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _neonGreen, width: 1.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _gerando ? null : _compartilharPDF,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.share, color: _neonGreen, size: 20),
                        SizedBox(width: 10),
                        Text('COMPARTILHAR', style: TextStyle(
                          color: _neonGreen, fontWeight: FontWeight.w900,
                          fontSize: 13, letterSpacing: 0.8,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Botão IMPRIMIR
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _neonCyan, width: 1.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _gerando ? null : _imprimirPDF,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.print, color: _neonCyan, size: 20),
                        SizedBox(width: 10),
                        Text('IMPRIMIR', style: TextStyle(
                          color: _neonCyan, fontWeight: FontWeight.w900,
                          fontSize: 13, letterSpacing: 0.8,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ===== DICA =====
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _neonGold.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: _neonGold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('DICA', style: TextStyle(
                          color: _neonGold, fontSize: 11,
                          fontWeight: FontWeight.w900, letterSpacing: 0.8,
                        )),
                        SizedBox(height: 4),
                        Text(
                          'O PDF inclui resultado financeiro do mês (faturamento, lucro/prejuízo) quando há viagens com nota cadastrada.',
                          style: TextStyle(color: _textMuted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============ TELA DE PREVIEW ============

class _PdfPreviewScreen extends StatelessWidget {
  final List<int> pdfBytes;
  final int mes;
  final int ano;

  const _PdfPreviewScreen({
    required this.pdfBytes,
    required this.mes,
    required this.ano,
  });

  static const Color _background = Color(0xFF0A0E1A);
  static const Color _neonPink = Color(0xFFFF4D6D);
  static const Color _textMain = Color(0xFFE8ECF4);
  static const Color _neonGold = Color(0xFFE8C547);

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _background),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _textMain,
          elevation: 0,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_neonPink, _neonGold],
            ).createShader(bounds),
            child: Text(
              '${_meses[mes - 1].toUpperCase()} / $ano',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: _neonPink),
        ),
        body: PdfPreview(
          build: (_) async => Uint8List.fromList(pdfBytes),
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: 'relatorio_${ano}_${mes.toString().padLeft(2, '0')}.pdf',
        ),
      ),
    );
  }
}