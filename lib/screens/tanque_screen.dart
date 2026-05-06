import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kTanqueKey     = 'tanque_estacionario_v1';
const String kTanqueHistKey = 'tanque_historico_v1';

class TanqueScreen extends StatefulWidget {
  const TanqueScreen({super.key});

  static Future<double> getSaldo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('${kTanqueKey}_saldo') ?? 0.0;
  }

  static Future<double> getPrecoPorLitro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('${kTanqueKey}_preco') ?? 0.0;
  }

  static Future<void> debitarLitros(double litros) async {
    if (litros <= 0) return;
    final prefs     = await SharedPreferences.getInstance();
    final saldo     = prefs.getDouble('${kTanqueKey}_saldo') ?? 0.0;
    final novoSaldo = (saldo - litros).clamp(0.0, double.infinity);
    await prefs.setDouble('${kTanqueKey}_saldo', novoSaldo);
    final rawHist = prefs.getString(kTanqueHistKey);
    List<Map<String, dynamic>> hist = [];
    if (rawHist != null && rawHist.trim().isNotEmpty) {
      try {
        final dec = jsonDecode(rawHist);
        if (dec is List) {
          hist = dec.whereType<Map>()
              .map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    hist.add({
      'tipo':   'saida',
      'date':   DateTime.now().toIso8601String(),
      'litros': litros,
    });
    await prefs.setString(kTanqueHistKey, jsonEncode(hist));
  }

  @override
  State<TanqueScreen> createState() => _TanqueScreenState();
}

class _TanqueScreenState extends State<TanqueScreen> {
  static const int    kAlertaLitros = 1000;
  static const double kCapacidadeMax = 10000.0; // ← tanque de 10 mil litros
  static const Color _background   = Color(0xFF0A0E1A);
  static const Color _surface      = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan     = Color(0xFF00E5FF);
  static const Color _neonOrange   = Color(0xFFFF6B35);
  static const Color _neonGreen    = Color(0xFF00FF88);
  static const Color _neonPink     = Color(0xFFFF4D6D);
  static const Color _neonGold     = Color(0xFFE8C547);
  static const Color _textMain     = Color(0xFFE8ECF4);
  static const Color _textMuted    = Color(0xFF8A93A8);

  final _litrosCtrl     = TextEditingController();
  final _valorTotalCtrl = TextEditingController();

  double _saldoLitros   = 0;
  double _precoPorLitro = 0;
  List<Map<String, dynamic>> _historico = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _litrosCtrl.addListener(() => setState(() {}));
    _valorTotalCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _litrosCtrl.dispose();
    _valorTotalCtrl.dispose();
    super.dispose();
  }

  double _parseNum(String s) {
    if (s.trim().isEmpty) return 0.0;
    String valor = s.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (valor.contains('.') && valor.contains(',')) {
      valor = valor.replaceAll('.', '');
      valor = valor.replaceAll(',', '.');
    } else if (valor.contains(',')) {
      valor = valor.replaceAll(',', '.');
    } else if (valor.contains('.') && valor.length > 4) {
      valor = valor.replaceAll('.', '');
    }
    return double.tryParse(valor) ?? 0.0;
  }

  String _fmt2(double v) {
    final s       = v.toStringAsFixed(2);
    final partes  = s.split('.');
    final inteiro = partes[0];
    final decimal = partes[1];
    final negativo= inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;
    final buffer  = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numeros[i]);
    }
    return '${negativo ? '-' : ''}${buffer.toString()},$decimal';
  }

  String _money(double v) => 'R\$ ${_fmt2(v)}';

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}/'
          '${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return '-'; }
  }

  double get _litrosEntrada   => _parseNum(_litrosCtrl.text);
  double get _valorTotalNota  => _parseNum(_valorTotalCtrl.text);
  double get _precoPorLitroCalc =>
      (_litrosEntrada > 0 && _valorTotalNota > 0)
          ? _valorTotalNota / _litrosEntrada : 0.0;
  bool get _tanqueBaixo => _saldoLitros > 0 && _saldoLitros < kAlertaLitros;

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _saldoLitros   = prefs.getDouble('${kTanqueKey}_saldo') ?? 0.0;
    _precoPorLitro = prefs.getDouble('${kTanqueKey}_preco') ?? 0.0;
    final rawHist  = prefs.getString(kTanqueHistKey);
    _historico = [];
    if (rawHist != null && rawHist.trim().isNotEmpty) {
      try {
        final dec = jsonDecode(rawHist);
        if (dec is List) {
          _historico = dec.whereType<Map>()
              .map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (_tanqueBaixo) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showAlertaBaixo());
    }
  }

  Future<void> _salvarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${kTanqueKey}_saldo', _saldoLitros);
    await prefs.setDouble('${kTanqueKey}_preco', _precoPorLitro);
    await prefs.setString(kTanqueHistKey, jsonEncode(_historico));
  }

  Future<void> _lancarEntrada() async {
    final litros     = _litrosEntrada;
    final valorTotal = _valorTotalNota;
    if (litros <= 0)     { _showErro('Informe a quantidade de litros.'); return; }
    if (valorTotal <= 0) { _showErro('Informe o valor total da nota.');  return; }
    final preco = valorTotal / litros;
    setState(() {
      _saldoLitros   += litros;
      _precoPorLitro  = preco;
      _historico.add({
        'tipo': 'entrada', 'date': DateTime.now().toIso8601String(),
        'litros': litros, 'valorTotal': valorTotal, 'precoPorLitro': preco,
      });
    });
    await _salvarEstado();
    _litrosCtrl.clear();
    _valorTotalCtrl.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _neonGreen.withOpacity(0.15),
      content: Row(children: [
        const Icon(Icons.check_circle, color: _neonGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          '${_fmt2(litros)} L adicionados! Preco: ${_money(preco)}/L',
          style: const TextStyle(color: _neonGreen, fontWeight: FontWeight.w700))),
      ]),
    ));
  }

  Future<void> _excluirRegistro(int index) async {
    final reg    = _historico[index];
    final tipo   = reg['tipo']?.toString() ?? '';
    final litros = (reg['litros'] is num)
        ? (reg['litros'] as num).toDouble() : 0.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: _neonPink),
          SizedBox(width: 8),
          Text('Excluir registro?', style: TextStyle(color: _textMain)),
        ]),
        content: const Text('Isso ajustara o saldo do tanque.',
            style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: _textMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      if (tipo == 'entrada') {
        _saldoLitros = (_saldoLitros - litros).clamp(0, double.infinity);
      } else {
        _saldoLitros += litros;
      }
      _historico.removeAt(index);
    });
    await _salvarEstado();
  }

  void _showErro(String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _surface,
      title: const Row(children: [
        Icon(Icons.error_outline, color: _neonPink),
        SizedBox(width: 8),
        Text('Atencao', style: TextStyle(color: _textMain)),
      ]),
      content: Text(msg, style: const TextStyle(color: _textMuted)),
      actions: [FilledButton(
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(backgroundColor: _neonOrange),
        child: const Text('OK, vou revisar',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)))],
    ));
  }

  void _showAlertaBaixo() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _surface,
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: _neonOrange, size: 28),
        SizedBox(width: 8),
        Text('Tanque Baixo!', style: TextStyle(
            color: _neonOrange, fontWeight: FontWeight.w900)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo atual: ${_fmt2(_saldoLitros)} L',
            style: const TextStyle(color: _textMain, fontSize: 18,
                fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('O tanque esta abaixo de $kAlertaLitros litros!',
            style: const TextStyle(color: _textMuted, fontSize: 13)),
        ]),
      actions: [FilledButton(
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(backgroundColor: _neonOrange),
        child: const Text('Entendido',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)))],
    ));
  }

  Widget _kpiCard(String label, String value, IconData icon, Color cor,
      {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.4), width: 1.2),
        boxShadow: [BoxShadow(color: cor.withOpacity(0.08), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(height: 36, width: 36,
            decoration: BoxDecoration(color: cor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: cor, size: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: cor,
              fontWeight: FontWeight.w800, letterSpacing: 0.5))),
        ]),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20,
            fontWeight: FontWeight.w900, color: _textMain)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11, color: _textMuted)),
        ],
      ]),
    );
  }

  InputDecoration _inputDeco({required String label, required String hint,
      required IconData icon, Color? cor}) {
    final c = cor ?? _neonCyan;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: _textMuted.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: c, size: 20),
      filled: true, fillColor: _surfaceLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.withOpacity(0.3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: 1.8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(useMaterial3: true, brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(primary: _neonCyan,
            surface: _surface, onPrimary: Colors.black, onSurface: _textMain)),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background, foregroundColor: _textMain, elevation: 0,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
                colors: [_neonCyan, _neonGold]).createShader(bounds),
            child: const Text('TANQUE ESTACIONARIO',
              style: TextStyle(fontWeight: FontWeight.w900,
                  letterSpacing: 1.0, color: Colors.white))),
          iconTheme: const IconThemeData(color: _neonCyan),
          actions: [IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh, color: _neonCyan))],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _neonCyan))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [

                  if (_tanqueBaixo)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _neonOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _neonOrange, width: 1.5)),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: _neonOrange, size: 26),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TANQUE BAIXO!', style: TextStyle(
                                color: _neonOrange, fontWeight: FontWeight.w900,
                                fontSize: 13, letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text('Saldo de ${_fmt2(_saldoLitros)} L '
                                'esta abaixo de $kAlertaLitros L!',
                              style: const TextStyle(
                                  color: _textMain, fontSize: 12)),
                          ])),
                      ]),
                    ),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [_neonCyan.withOpacity(0.15),
                            _neonGold.withOpacity(0.06)]),
                      border: Border.all(color: _neonCyan.withOpacity(0.35))),
                    child: Row(children: [
                      Container(height: 52, width: 52,
                        decoration: BoxDecoration(
                          color: _neonCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.propane_tank_outlined,
                            color: _neonCyan, size: 28)),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tanque Estacionario', style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900,
                              color: _textMain)),
                          SizedBox(height: 4),
                          Text('Controle de diesel fixo. Saldo '
                              'descontado a cada abastecimento.',
                            style: TextStyle(fontSize: 11, color: _textMuted)),
                        ])),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(child: _kpiCard('SALDO ATUAL',
                      '${_fmt2(_saldoLitros)} L',
                      Icons.local_gas_station_outlined,
                      _tanqueBaixo ? _neonOrange : _neonCyan,
                      sub: _tanqueBaixo ? 'ABAIXO DO MINIMO' : 'Disponivel')),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiCard('PRECO ATUAL/L',
                      _precoPorLitro > 0 ? _money(_precoPorLitro) : '--',
                      Icons.attach_money, _neonGold, sub: 'Ultima compra')),
                  ]),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _neonGreen.withOpacity(0.25))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: const [
                          Icon(Icons.add_circle_outline,
                              color: _neonGreen, size: 22),
                          SizedBox(width: 8),
                          Text('Registrar entrada de diesel',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w900, color: _textMain)),
                        ]),
                        const SizedBox(height: 14),
                        TextField(controller: _litrosCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(color: _textMain),
                          decoration: _inputDeco(label: 'Litros comprados',
                              hint: 'Ex: 5000',
                              icon: Icons.water_drop_outlined, cor: _neonCyan)),
                        const SizedBox(height: 10),
                        TextField(controller: _valorTotalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(color: _textMain),
                          decoration: _inputDeco(
                              label: 'Valor total da nota (R\$)',
                              hint: 'Ex: 38700,00',
                              icon: Icons.receipt_long_outlined, cor: _neonGold)),
                        if (_litrosEntrada > 0 && _valorTotalNota > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _neonGold.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _neonGold.withOpacity(0.3))),
                            child: Row(children: [
                              const Icon(Icons.calculate_outlined,
                                  color: _neonGold, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Preco por litro: ${_money(_precoPorLitroCalc)}/L',
                                style: const TextStyle(color: _neonGold,
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            ])),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                                colors: [_neonGreen, _neonCyan]),
                            boxShadow: [BoxShadow(
                                color: _neonGreen.withOpacity(0.35),
                                blurRadius: 16)]),
                          child: Material(color: Colors.transparent,
                            child: InkWell(onTap: _lancarEntrada,
                              borderRadius: BorderRadius.circular(14),
                              child: Center(child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add, color: Colors.black),
                                  SizedBox(width: 8),
                                  Text('ADICIONAR AO TANQUE',
                                    style: TextStyle(color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14, letterSpacing: 0.6)),
                                ])))),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (_tanqueBaixo
                          ? _neonOrange : _neonCyan).withOpacity(0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('NIVEL DO TANQUE', style: TextStyle(
                                color: _textMuted, fontSize: 11,
                                fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            Text('${_fmt2(_saldoLitros)} L',
                              style: TextStyle(
                                  color: _tanqueBaixo ? _neonOrange : _neonCyan,
                                  fontSize: 14, fontWeight: FontWeight.w900)),
                          ]),
                        const SizedBox(height: 10),
                        Builder(builder: (ctx) {
                          final pct = (_saldoLitros / kCapacidadeMax).clamp(0.0, 1.0);
                          final cor = _tanqueBaixo ? _neonOrange : _neonGreen;
                          return Column(children: [
                            Stack(children: [
                              Container(height: 20,
                                decoration: BoxDecoration(color: _surfaceLight,
                                    borderRadius: BorderRadius.circular(10))),
                              LayoutBuilder(builder: (c, cons) => Container(
                                height: 20, width: cons.maxWidth * pct,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [cor, cor.withOpacity(0.6)]),
                                  borderRadius: BorderRadius.circular(10)))),
                            ]),
                            const SizedBox(height: 6),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('0 L', style: TextStyle(
                                    color: _textMuted, fontSize: 10)),
                                Text(
                                  '${((_saldoLitros / kCapacidadeMax) * 100).toStringAsFixed(0)}% de ${_fmt2(kCapacidadeMax)} L',
                                  style: const TextStyle(
                                      color: _textMuted, fontSize: 10)),
                                Text('${_fmt2(kCapacidadeMax)} L',
                                  style: const TextStyle(
                                      color: _textMuted, fontSize: 10)),
                              ]),
                          ]);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(children: [
                    const Icon(Icons.history, color: _neonCyan, size: 20),
                    const SizedBox(width: 8),
                    const Text('Historico de movimentacoes',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w900, color: _textMain)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _neonCyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _neonCyan.withOpacity(0.3))),
                      child: Text('${_historico.length}',
                        style: const TextStyle(color: _neonCyan,
                            fontWeight: FontWeight.w800, fontSize: 11))),
                  ]),
                  const SizedBox(height: 10),

                  if (_historico.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _textMuted.withOpacity(0.15))),
                      child: const Center(child: Text(
                          'Nenhuma movimentacao registrada.',
                          style: TextStyle(color: _textMuted))))
                  else
                    ...(_historico.reversed.toList().asMap().entries.map((e) {
                      final i          = _historico.length - 1 - e.key;
                      final reg        = e.value;
                      final tipo       = reg['tipo']?.toString() ?? '';
                      final isEntrada  = tipo == 'entrada';
                      final litros     = (reg['litros'] is num)
                          ? (reg['litros'] as num).toDouble() : 0.0;
                      final valorTotal = (reg['valorTotal'] is num)
                          ? (reg['valorTotal'] as num).toDouble() : 0.0;
                      final preco      = (reg['precoPorLitro'] is num)
                          ? (reg['precoPorLitro'] as num).toDouble() : 0.0;
                      final data       = _fmtDate(reg['date']?.toString());
                      final cor        = isEntrada ? _neonGreen : _neonPink;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cor.withOpacity(0.25))),
                        child: Row(children: [
                          Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: cor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                              isEntrada ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: cor, size: 22)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6)),
                                  child: Text(isEntrada ? 'ENTRADA' : 'SAIDA',
                                    style: TextStyle(color: cor, fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8))),
                                const SizedBox(width: 6),
                                Text(data, style: const TextStyle(
                                    color: _textMuted, fontSize: 11)),
                              ]),
                              const SizedBox(height: 5),
                              Text('${isEntrada ? '+' : '-'}${_fmt2(litros)} L',
                                style: TextStyle(color: cor, fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                              if (isEntrada && valorTotal > 0)
                                Text(
                                  'Nota: ${_money(valorTotal)}  |  '
                                  '${_money(preco)}/L',
                                  style: const TextStyle(
                                      color: _textMuted, fontSize: 11)),
                            ])),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: _neonPink, size: 20),
                            onPressed: () => _excluirRegistro(i)),
                        ]),
                      );
                    })),

                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}