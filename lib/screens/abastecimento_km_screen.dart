import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/voucher_print_service.dart';
import 'tanque_screen.dart';

class AbastecimentoKmScreen extends StatefulWidget {
  const AbastecimentoKmScreen({super.key});

  @override
  State<AbastecimentoKmScreen> createState() => _AbastecimentoKmScreenState();
}

class _AbastecimentoKmScreenState extends State<AbastecimentoKmScreen> {
  static const String _vehiclesKey    = 'veiculos_v1';
  static const String _fuelKeyPrefix  = 'fuel_records_';
  static const String _companyNameKey = 'company_name';
  static const double _margem         = 0.08;

  static const Color _background   = Color(0xFF0A0E1A);
  static const Color _surface      = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan     = Color(0xFF00E5FF);
  static const Color _neonPurple   = Color(0xFFB388FF);
  static const Color _neonOrange   = Color(0xFFFF6B35);
  static const Color _neonGreen    = Color(0xFF00FF88);
  static const Color _neonPink     = Color(0xFFFF4D6D);
  static const Color _neonGold     = Color(0xFFE8C547);
  static const Color _textMain     = Color(0xFFE8ECF4);
  static const Color _textMuted    = Color(0xFF8A93A8);

  static const double _litrosMaxAbastecimento = 600.0;
  static const double _consumoPrevistoMax     = 18.0;
  static const double _consumoMin             = 1.0;
  static const double _consumoMax             = 18.0;

  bool _loadingVehicles = true;
  bool _loadingRecords  = false;
  bool _salvando        = false;

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _records  = [];
  String? _selectedVehicleId;

  final _distanciaIdaCtrl = TextEditingController();
  final _consumoCtrl      = TextEditingController();
  final _precoCtrl        = TextEditingController();
  final _litrosFinalCtrl  = TextEditingController();
  final _kmAtualCtrl      = TextEditingController();
  final _valorNotaCtrl    = TextEditingController();
  final _motoristaCtrl    = TextEditingController();

  double? _ultimoKmRegistrado;
  double _tanqueSaldo      = 0;
  double _tanquePrecoLitro = 0;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _carregarDadosTanque();
    _distanciaIdaCtrl.addListener(() => setState(() {}));
    _consumoCtrl.addListener(() => setState(() {}));
    _precoCtrl.addListener(() => setState(() {}));
    _litrosFinalCtrl.addListener(() => setState(() {}));
    _kmAtualCtrl.addListener(() => setState(() {}));
    _valorNotaCtrl.addListener(() => setState(() {}));
    _motoristaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _distanciaIdaCtrl.dispose();
    _consumoCtrl.dispose();
    _precoCtrl.dispose();
    _litrosFinalCtrl.dispose();
    _kmAtualCtrl.dispose();
    _valorNotaCtrl.dispose();
    _motoristaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosTanque() async {
    final saldo = await TanqueScreen.getSaldo();
    final preco = await TanqueScreen.getPrecoPorLitro();
    if (!mounted) return;
    setState(() {
      _tanqueSaldo      = saldo;
      _tanquePrecoLitro = preco;
      if (_precoCtrl.text.trim().isEmpty && preco > 0) {
        _precoCtrl.text = preco.toStringAsFixed(2).replaceAll('.', ',');
      }
    });
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

  String _fmtInt(double v) {
    final inteiro = v.toInt().toString();
    final negativo= inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;
    final buffer  = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numeros[i]);
    }
    return '${negativo ? '-' : ''}${buffer.toString()}';
  }

  String _money(double v) => 'R\$ ${_fmt2(v)}';

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d   = DateTime.parse(iso);
      final dia = d.day.toString().padLeft(2, '0');
      final mes = d.month.toString().padLeft(2, '0');
      return '$dia/$mes/${d.year}';
    } catch (_) { return iso; }
  }

  Future<void> _loadVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_vehiclesKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded.whereType<Map>()
              .map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    final selectedId = list.isNotEmpty ? (list.first['id']?.toString()) : null;
    setState(() {
      _vehicles          = list;
      _selectedVehicleId = selectedId;
      _loadingVehicles   = false;
    });
    if (selectedId != null) await _loadRecords(selectedId);
  }

  Future<void> _loadRecords(String vehicleId) async {
    setState(() => _loadingRecords = true);
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('$_fuelKeyPrefix$vehicleId');
    List<Map<String, dynamic>> records = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          records = decoded.whereType<Map>()
              .map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    double? ultimoKm;
    if (records.isNotEmpty) {
      final last = records.last;
      final km   = (last['kmAtual'] is num)
          ? (last['kmAtual'] as num).toDouble()
          : _parseNum((last['kmAtual'] ?? '').toString());
      if (km > 0) ultimoKm = km;
    }
    if (!mounted) return;
    setState(() {
      _records            = records;
      _ultimoKmRegistrado = ultimoKm;
      _loadingRecords     = false;
    });
  }

  // ===== GETTERS =====
  double get _distanciaIda    => _parseNum(_distanciaIdaCtrl.text);
  double get _consumo         => _parseNum(_consumoCtrl.text);
  double get _preco           => _parseNum(_precoCtrl.text);
  double get _kmAtual         => _parseNum(_kmAtualCtrl.text);
  double get _litrosManual    => _parseNum(_litrosFinalCtrl.text);
  double get _valorNota       => _parseNum(_valorNotaCtrl.text);
  double get _distanciaTotal  => _distanciaIda > 0 ? _distanciaIda * 2 : 0.0;
  double get _litrosBase      => (_distanciaIda > 0 && _consumo > 0)
      ? (_distanciaIda * 2) / _consumo : 0.0;
  double get _litrosComMargem => _litrosBase > 0 ? _litrosBase * (1 + _margem) : 0.0;
  double get _custoCalc       => (_litrosManual > 0 && _preco > 0)
      ? _litrosManual * _preco : 0.0;

  double get _kmRodadoReal {
    if (_ultimoKmRegistrado == null || _kmAtual <= 0) return 0.0;
    final dif = _kmAtual - _ultimoKmRegistrado!;
    return dif > 0 ? dif : 0.0;
  }

  double get _kmPorLitroReal {
    if (_kmRodadoReal <= 0 || _litrosManual <= 0) return 0.0;
    return _kmRodadoReal / _litrosManual;
  }

  double get _custoPorKmReal {
    if (_kmRodadoReal <= 0 || _custoCalc <= 0) return 0.0;
    return _custoCalc / _kmRodadoReal;
  }

  double? get _lucroBruto =>
      _valorNota > 0 ? _valorNota - _custoCalc : null;

  double? get _margemLucroPct {
    if (_valorNota <= 0 || _lucroBruto == null) return null;
    return (_lucroBruto! / _valorNota) * 100;
  }

  bool get _consumoSuspeito => false;

  double _getRecordDouble(Map<String, dynamic> r, String key) {
    final v = r[key];
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return _parseNum(v.toString());
  }

  double get _totalLitrosHistorico {
    double t = 0;
    for (final r in _records) t += _getRecordDouble(r, 'litrosFinal');
    return t;
  }

  double get _totalCustoHistorico {
    double t = 0;
    for (final r in _records) t += _getRecordDouble(r, 'custoFinal');
    return t;
  }

  List<String> _validarTudoAntesDeSalvar() {
    final erros = <String>[];

    if (_litrosManual > _litrosMaxAbastecimento) {
      erros.add(
        'Litros abastecidos (${_fmt2(_litrosManual)} L) ultrapassam o maximo de ${_fmt2(_litrosMaxAbastecimento)} L. Verifique o valor.',
      );
    }

    if (_consumo > _consumoPrevistoMax) {
      erros.add(
        'Consumo previsto (${_fmt2(_consumo)} km/L) e alto demais (maximo: ${_fmt2(_consumoPrevistoMax)} km/L).',
      );
    }

    if (_ultimoKmRegistrado != null && _kmAtual > 0) {
      if (_kmAtual < _ultimoKmRegistrado!) {
        erros.add(
          'KM atual (${_fmtInt(_kmAtual)}) e MENOR que o ultimo registrado (${_fmtInt(_ultimoKmRegistrado!)}). O hodometro nao anda para tras!',
        );
      }
    }

    return erros;
  }

  Future<void> _saveRecord() async {
    if (_selectedVehicleId == null) return;

    if (_distanciaIda <= 0 || _consumo <= 0 || _preco <= 0 ||
        _litrosManual <= 0 || _kmAtual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatorios.')));
      return;
    }

    final erros = _validarTudoAntesDeSalvar();
    if (erros.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _surface,
          title: const Row(children: [
            Icon(Icons.block, color: _neonPink, size: 24),
            SizedBox(width: 8),
            Expanded(child: Text('Nao e possivel salvar',
                style: TextStyle(color: _textMain, fontSize: 16))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Os dados digitados tem inconsistencias:',
                  style: TextStyle(color: _textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              ...erros.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _neonOrange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e, style: const TextStyle(
                        color: _textMain, fontSize: 12.5, height: 1.4))),
                  ]),
              )),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: _neonCyan),
              child: const Text('OK, vou revisar')),
          ],
        ),
      );
      setState(() => _salvando = false);
      return;
    }

    setState(() => _salvando = true);

    final prefs = await SharedPreferences.getInstance();
    final key   = '$_fuelKeyPrefix$_selectedVehicleId';

    final novo = {
      'date':            DateTime.now().toIso8601String(),
      'distanciaIdaKm':  _distanciaIda,
      'distanciaKm':     _distanciaIda * 2,
      'consumoKmL':      _consumo,
      'precoLitro':      _preco,
      'litrosBase':      _litrosBase,
      'litrosComMargem': _litrosComMargem,
      'litrosFinal':     _litrosManual,
      'custoFinal':      _custoCalc,
      'kmAtual':         _kmAtual,
      'kmAnterior':      _ultimoKmRegistrado,
      'kmRodadoReal':    _kmRodadoReal > 0 ? _kmRodadoReal : null,
      'kmPorLitroReal':  _kmPorLitroReal > 0 ? _kmPorLitroReal : null,
      'custoPorKmReal':  _custoPorKmReal > 0 ? _custoPorKmReal : null,
      'valorNota':       _valorNota > 0 ? _valorNota : null,
      'lucroBruto':      _lucroBruto,
      'margemLucroPct':  _margemLucroPct,
      'motorista':       _motoristaCtrl.text.trim(),
      'precoTanque':     _tanquePrecoLitro > 0 ? _tanquePrecoLitro : null,
      'descricao':       'Calculo por KM (ida+volta, margem 8%)',
    };

    final atualizados = [..._records, novo];
    await prefs.setString(key, jsonEncode(atualizados));

    if (_litrosManual > 0 && _tanqueSaldo > 0) {
      await TanqueScreen.debitarLitros(_litrosManual);
      await _carregarDadosTanque();
    }

    if (!mounted) return;

    _distanciaIdaCtrl.clear();
    _consumoCtrl.clear();
    _precoCtrl.clear();
    _litrosFinalCtrl.clear();
    _kmAtualCtrl.clear();
    _valorNotaCtrl.clear();
    _motoristaCtrl.clear();

    setState(() => _salvando = false);
    await _loadRecords(_selectedVehicleId!);
    await _carregarDadosTanque();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surface,
        content: Row(children: const [
          Icon(Icons.check_circle, color: _neonGreen, size: 18),
          SizedBox(width: 8),
          Text('Abastecimento salvo!',
              style: TextStyle(color: _neonGreen, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _deleteRecord(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Apagar abastecimento',
            style: TextStyle(color: _textMain)),
        content: const Text(
          'Deseja apagar esse abastecimento? Essa acao nao pode ser desfeita.',
          style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _neonCyan))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true || _selectedVehicleId == null) return;

    final prefs       = await SharedPreferences.getInstance();
    final key         = '$_fuelKeyPrefix$_selectedVehicleId';
    final atualizados = [..._records];
    atualizados.removeAt(index);
    await prefs.setString(key, jsonEncode(atualizados));
    await _loadRecords(_selectedVehicleId!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: _surface,
        content: Text('Abastecimento removido.',
            style: TextStyle(color: _textMain))));
  }

  Future<void> _imprimirVoucher(Map<String, dynamic> r) async {
    final btLigado = await VoucherPrintService.bluetoothLigado();
    if (!btLigado) {
      if (!mounted) return;
      _showError('Bluetooth desligado',
          'Ligue o Bluetooth e pareie a impressora antes de tentar novamente.');
      return;
    }
    final impressoras = await VoucherPrintService.listarImpressoras();
    if (impressoras.isEmpty) {
      if (!mounted) return;
      _showError('Nenhuma impressora pareada',
          'Pareie a impressora nas configuracoes de Bluetooth.');
      return;
    }
    BluetoothInfo? selecionada;
    if (impressoras.length == 1) {
      selecionada = impressoras.first;
    } else {
      selecionada = await _escolherImpressora(impressoras);
    }
    if (selecionada == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: _neonCyan)));

    final prefs        = await SharedPreferences.getInstance();
    final empresa      = prefs.getString(_companyNameKey)?.trim() ?? 'Gestor de Frota';
    final precoTanque  = _getRecordDouble(r, 'precoTanque');
    final numeroVale   = await VoucherPrintService.proximoNumeroVale();

    final voucher = VoucherData(
      empresa:          empresa.isEmpty ? 'Gestor de Frota' : empresa,
      veiculoLabel:     _vehicleLabelById(_selectedVehicleId),
      motorista:        (r['motorista'] ?? '').toString(),
      data:             _parseRecordDate(r),
      kmAtual:          _getRecordDouble(r, 'kmAtual'),
      distanciaTotalKm: _getRecordDouble(r, 'distanciaKm'),
      litros:           _getRecordDouble(r, 'litrosFinal'),
      precoLitro:       _getRecordDouble(r, 'precoLitro'),
      custoTotal:       _getRecordDouble(r, 'custoFinal'),
      valorNota:        _getRecordDouble(r, 'valorNota'),
      precoTanque:      precoTanque > 0 ? precoTanque : null,
      numeroVale:       numeroVale,
    );

    final result = await VoucherPrintService.imprimirVoucher(
      impressora: selecionada,
      voucher: voucher,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result.sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: _surface,
          content: Text(result.mensagem,
              style: const TextStyle(color: _textMain))));
    } else {
      _showError('Erro ao imprimir', result.mensagem);
    }
  }

  DateTime _parseRecordDate(Map<String, dynamic> r) {
    try { return DateTime.parse(r['date'].toString()); }
    catch (_) { return DateTime.now(); }
  }

  Future<BluetoothInfo?> _escolherImpressora(List<BluetoothInfo> lista) async {
    return await showModalBottomSheet<BluetoothInfo>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Escolha a impressora',
                style: TextStyle(color: _textMain, fontSize: 16,
                    fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Toque na impressora para imprimir o voucher.',
                style: TextStyle(color: _textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              ...lista.map((imp) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _neonCyan.withOpacity(0.3))),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _neonCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.print, color: _neonCyan)),
                  title: Text(imp.name, style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w700)),
                  subtitle: Text(imp.macAdress, style: const TextStyle(
                      color: _textMuted, fontSize: 11)),
                  onTap: () => Navigator.pop(context, imp)))),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Row(children: [
          const Icon(Icons.error_outline, color: _neonPink),
          const SizedBox(width: 8),
          Text(titulo, style: const TextStyle(color: _textMain)),
        ]),
        content: Text(msg, style: const TextStyle(color: _textMuted)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _neonCyan),
            child: const Text('OK')),
        ],
      ),
    );
  }

  String _vehicleLabelById(String? id) {
    if (id == null) return '-';
    final v     = _vehicles.firstWhere(
      (e) => (e['id']?.toString() ?? '') == id,
      orElse: () => <String, dynamic>{});
    final placa = (v['placa'] ?? '').toString();
    final tipo  = (v['tipo'] ?? v['modelo'] ?? '').toString();
    return tipo.trim().isEmpty ? placa : '$placa - $tipo';
  }

  Widget _infoBox(String label, String value, {Color? cor}) {
    final c = cor ?? _neonCyan;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: c,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w900, color: _textMain)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label, required String hint,
    required IconData icon, Color? iconColor,
  }) {
    final c = iconColor ?? _neonCyan;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: _textMuted.withOpacity(0.5), fontSize: 12),
      filled: true, fillColor: _surface,
      prefixIcon: Icon(icon, color: c, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.withOpacity(0.3), width: 1.2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.withOpacity(0.3), width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingVehicles) {
      return Theme(
        data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _background),
        child: const Scaffold(backgroundColor: _background,
          body: Center(child: CircularProgressIndicator(color: _neonCyan))));
    }

    if (_vehicles.isEmpty) {
      return Theme(
        data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _background),
        child: Scaffold(
          backgroundColor: _background,
          appBar: AppBar(backgroundColor: _background,
              foregroundColor: _textMain,
              title: const Text('Abastecimento')),
          body: const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhum veiculo cadastrado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted))))));
    }

    return Theme(
      data: ThemeData(
        useMaterial3: true, brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _neonCyan, surface: _surface,
          onPrimary: _background, onSurface: _textMain)),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background, foregroundColor: _textMain, elevation: 0,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_neonCyan, _neonPurple]).createShader(bounds),
            child: const Text('ABASTECIMENTO',
              style: TextStyle(fontWeight: FontWeight.w900,
                  letterSpacing: 1.0, color: Colors.white))),
          iconTheme: const IconThemeData(color: _neonCyan),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ===== BANNER TANQUE =====
            if (_tanqueSaldo > 0 || _tanquePrecoLitro > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _neonGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _neonGold.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.propane_tank_outlined,
                      color: _neonGold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TANQUE ESTACIONARIO',
                        style: TextStyle(color: _neonGold, fontSize: 10,
                            fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(
                        'Saldo: ${_fmt2(_tanqueSaldo)} L  |  '
                        'Preco/L: ${_tanquePrecoLitro > 0 ? _money(_tanquePrecoLitro) : "--"}',
                        style: const TextStyle(color: _textMain,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    ])),
                  if (_tanqueSaldo < 1000 && _tanqueSaldo > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _neonOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Text('BAIXO', style: TextStyle(
                          color: _neonOrange, fontSize: 9,
                          fontWeight: FontWeight.w900))),
                ]),
              ),

            // ===== VEÍCULO =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_neonCyan.withOpacity(0.18),
                      _neonPurple.withOpacity(0.08)]),
                border: Border.all(color: _neonCyan.withOpacity(0.4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.directions_car, color: _neonCyan, size: 18),
                    SizedBox(width: 6),
                    Text('VEICULO SELECIONADO', style: TextStyle(
                        fontSize: 11, color: _neonCyan,
                        fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonCyan.withOpacity(0.3))),
                    child: DropdownButtonFormField<String>(
                      value: _selectedVehicleId,
                      isExpanded: true,
                      dropdownColor: _surface,
                      style: const TextStyle(color: _textMain, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                      items: _vehicles.map((v) {
                        final id = (v['id'] ?? '').toString();
                        return DropdownMenuItem(
                          value: id,
                          child: Text(_vehicleLabelById(id),
                              style: const TextStyle(color: _textMain)));
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedVehicleId = v);
                        _loadRecords(v);
                      },
                    ),
                  ),
                  if (_ultimoKmRegistrado != null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.speed, size: 16, color: _textMuted),
                      const SizedBox(width: 4),
                      Text('Ultimo KM registrado: ${_fmtInt(_ultimoKmRegistrado!)}',
                          style: const TextStyle(fontSize: 12, color: _textMuted)),
                    ]),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== FORMULÁRIO =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _surface,
                border: Border.all(color: _neonCyan.withOpacity(0.25))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: const [
                    Icon(Icons.edit_note, color: _neonCyan, size: 22),
                    SizedBox(width: 8),
                    Text('Dados do abastecimento', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: _textMain)),
                  ]),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _motoristaCtrl,
                    style: const TextStyle(color: _textMain),
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco(
                      label: 'Nome do motorista', hint: 'Ex: Joao Silva',
                      icon: Icons.person_outline, iconColor: _neonPurple)),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _distanciaIdaCtrl,
                    style: const TextStyle(color: _textMain),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDeco(
                      label: 'Distancia de ida (km)', hint: 'Ex: 120',
                      icon: Icons.route)),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _consumoCtrl,
                    style: const TextStyle(color: _textMain),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDeco(
                      label: 'Consumo previsto (km/L)', hint: 'Ex: 3,5',
                      icon: Icons.local_gas_station)),
                  const SizedBox(height: 10),

                  Stack(children: [
                    TextField(
                      controller: _precoCtrl,
                      style: const TextStyle(color: _textMain),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _inputDeco(
                        label: 'Preco por litro (R\$)', hint: 'Ex: 6,39',
                        icon: Icons.attach_money, iconColor: _neonGreen)),
                    if (_tanquePrecoLitro > 0)
                      Positioned(
                        right: 12, top: 0, bottom: 0,
                        child: Center(child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _neonGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                          child: Text('Tanque: ${_money(_tanquePrecoLitro)}',
                            style: const TextStyle(color: _neonGold,
                                fontSize: 9, fontWeight: FontWeight.w800))))),
                  ]),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _litrosFinalCtrl,
                    style: const TextStyle(color: _textMain),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDeco(
                      label: 'Litros abastecidos', hint: 'Ex: 300',
                      icon: Icons.water_drop)),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _kmAtualCtrl,
                    style: const TextStyle(color: _textMain),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDeco(
                      label: 'KM atual do veiculo', hint: 'Ex: 152000',
                      icon: Icons.speed, iconColor: _neonPurple)),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _valorNotaCtrl,
                    style: const TextStyle(color: _textMain),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _inputDeco(
                      label: 'Valor da nota/mercadoria (R\$)',
                      hint: 'Opcional - para calcular lucro',
                      icon: Icons.receipt_long, iconColor: _neonGreen)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== RESULTADOS =====
            if (_distanciaIda > 0 || _consumo > 0 || _preco > 0 ||
                _litrosManual > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _surfaceLight,
                  border: Border.all(color: _neonPurple.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: const [
                      Icon(Icons.calculate, color: _neonPurple, size: 22),
                      SizedBox(width: 8),
                      Text('Resultados', style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w900, color: _textMain)),
                    ]),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8, crossAxisSpacing: 8,
                      childAspectRatio: 2.4,
                      children: [
                        _infoBox('DISTANCIA TOTAL',
                            '${_fmt2(_distanciaTotal)} km', cor: _neonCyan),
                        _infoBox('LITROS BASE',
                            '${_fmt2(_litrosBase)} L', cor: _neonCyan),
                        _infoBox('COM MARGEM 8%',
                            '${_fmt2(_litrosComMargem)} L', cor: _neonOrange),
                        _infoBox('CUSTO TOTAL',
                            _money(_custoCalc), cor: _neonGreen),
                        if (_kmRodadoReal > 0)
                          _infoBox('KM RODADO',
                              '${_fmt2(_kmRodadoReal)} km', cor: _neonPurple),
                        if (_kmPorLitroReal > 0)
                          _infoBox('KM/L REAL',
                              _fmt2(_kmPorLitroReal), cor: _neonPurple),
                        if (_custoPorKmReal > 0)
                          _infoBox('CUSTO/KM',
                              _money(_custoPorKmReal), cor: _neonPurple),
                      ],
                    ),
                    if (_valorNota > 0 && _lucroBruto != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: _lucroBruto! >= 0
                                ? [_neonGreen.withOpacity(0.18),
                                   _neonGreen.withOpacity(0.05)]
                                : [_neonPink.withOpacity(0.18),
                                   _neonPink.withOpacity(0.05)]),
                          border: Border.all(
                            color: _lucroBruto! >= 0
                                ? _neonGreen.withOpacity(0.5)
                                : _neonPink.withOpacity(0.5),
                            width: 1.4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(_lucroBruto! >= 0
                                  ? Icons.trending_up : Icons.trending_down,
                                color: _lucroBruto! >= 0
                                    ? _neonGreen : _neonPink),
                              const SizedBox(width: 8),
                              Text(_lucroBruto! >= 0
                                  ? 'LUCRO BRUTO' : 'PREJUIZO',
                                style: TextStyle(
                                  color: _lucroBruto! >= 0
                                      ? _neonGreen : _neonPink,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8, fontSize: 13)),
                            ]),
                            const SizedBox(height: 6),
                            Text(_money(_lucroBruto!.abs()),
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _lucroBruto! >= 0
                                      ? _neonGreen : _neonPink)),
                            if (_margemLucroPct != null)
                              Text('Margem: ${_fmt2(_margemLucroPct!)}%',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ===== BOTÃO SALVAR =====
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                    colors: [_neonCyan, _neonPurple]),
                boxShadow: [BoxShadow(
                    color: _neonCyan.withOpacity(0.35), blurRadius: 18)]),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _salvando ? null : _saveRecord,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _salvando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _background))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.save_outlined, color: _background),
                              SizedBox(width: 10),
                              Text('SALVAR ABASTECIMENTO',
                                style: TextStyle(color: _background,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14, letterSpacing: 0.8)),
                            ])),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ===== HISTÓRICO =====
            Row(children: [
              const Icon(Icons.history, color: _neonCyan),
              const SizedBox(width: 8),
              const Text('Historico', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w900, color: _textMain)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _neonCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _neonCyan.withOpacity(0.3))),
                child: Text('${_records.length} registro(s)',
                  style: const TextStyle(color: _neonCyan,
                      fontWeight: FontWeight.w800, fontSize: 12))),
            ]),

            const SizedBox(height: 10),

            if (_records.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _neonGreen.withOpacity(0.08),
                  border: Border.all(color: _neonGreen.withOpacity(0.3))),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL LITROS', style: TextStyle(
                          fontSize: 10, color: _neonGreen,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text('${_fmt2(_totalLitrosHistorico)} L',
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w900, color: _textMain)),
                    ])),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL GASTO', style: TextStyle(
                          fontSize: 10, color: _neonGreen,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(_money(_totalCustoHistorico),
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w900, color: _textMain)),
                    ])),
                ]),
              ),

            const SizedBox(height: 12),

            if (_loadingRecords)
              const Padding(padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(
                    color: _neonCyan)))
            else if (_records.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _textMuted.withOpacity(0.2))),
                child: const Center(child: Text(
                  'Nenhum abastecimento registrado para esse veiculo.',
                  style: TextStyle(color: _textMuted))))
            else
              ..._records.reversed.toList().asMap().entries.map((entry) {
                final reverseIndex = entry.key;
                final r            = entry.value;
                final realIndex    = _records.length - 1 - reverseIndex;

                final data         = _fmtDate(r['date']?.toString());
                final kmAtual      = _getRecordDouble(r, 'kmAtual');
                final litros       = _getRecordDouble(r, 'litrosFinal');
                final preco        = _getRecordDouble(r, 'precoLitro');
                final custo        = _getRecordDouble(r, 'custoFinal');
                final distanciaIda = _getRecordDouble(r, 'distanciaIdaKm');
                final consumo      = _getRecordDouble(r, 'consumoKmL');
                final valorNota    = _getRecordDouble(r, 'valorNota');
                final lucro        = _getRecordDouble(r, 'lucroBruto');
                final kmPorL       = _getRecordDouble(r, 'kmPorLitroReal');
                final motorista    = (r['motorista'] ?? '').toString();
                final precoTanque  = _getRecordDouble(r, 'precoTanque');

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _neonCyan.withOpacity(0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _neonCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(data, style: const TextStyle(
                              color: _neonCyan, fontWeight: FontWeight.w800,
                              fontSize: 12))),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.print, color: _neonCyan),
                          onPressed: () => _imprimirVoucher(r),
                          tooltip: 'Imprimir voucher',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: _neonPink),
                          onPressed: () => _deleteRecord(realIndex),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36)),
                      ]),

                      if (motorista.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: _neonPurple),
                          const SizedBox(width: 4),
                          Text(motorista, style: const TextStyle(
                              fontSize: 12, color: _neonPurple,
                              fontWeight: FontWeight.w700)),
                        ]),
                      ],

                      if (precoTanque > 0) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.propane_tank_outlined,
                              size: 14, color: _neonGold),
                          const SizedBox(width: 4),
                          Text('Preco tanque: ${_money(precoTanque)}/L',
                            style: const TextStyle(fontSize: 11,
                                color: _neonGold, fontWeight: FontWeight.w700)),
                        ]),
                      ],

                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('KM: ${_fmtInt(kmAtual)}',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                            Text('Distancia: ${_fmt2(distanciaIda)} km (ida)',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                            Text('Consumo: ${_fmt2(consumo)} km/L',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                            if (kmPorL > 0)
                              Text('Real: ${_fmt2(kmPorL)} km/L',
                                style: const TextStyle(fontSize: 12,
                                    color: _neonGreen,
                                    fontWeight: FontWeight.w700)),
                          ])),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Litros: ${_fmt2(litros)}',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                            Text('Preco: ${_money(preco)}',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                            Text(_money(custo), style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900,
                                color: _neonGreen)),
                            if (valorNota > 0)
                              Text('Lucro: ${_money(lucro)}',
                                style: TextStyle(fontSize: 11,
                                  color: lucro >= 0 ? _neonGreen : _neonPink,
                                  fontWeight: FontWeight.w700)),
                          ])),
                      ]),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}