import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PneusScreen extends StatefulWidget {
  const PneusScreen({super.key});

  @override
  State<PneusScreen> createState() => _PneusScreenState();
}

class _PneusScreenState extends State<PneusScreen> {
  static const String _vehiclesKey = 'veiculos_v1';
  static const String _tireKeyPrefix = 'tire_records_';

  // ============ CORES DARK NEON ============
  static const Color _background = Color(0xFF0A0E1A);
  static const Color _surface = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonPurple = Color(0xFFB388FF);
  static const Color _neonOrange = Color(0xFFFF6B35);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonPink = Color(0xFFFF4D6D);
  static const Color _textMain = Color(0xFFE8ECF4);
  static const Color _textMuted = Color(0xFF8A93A8);

  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;

  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();
  final _quantidadeCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  DateTime _data = DateTime.now();
  List<Map<String, dynamic>> _records = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _fornecedorCtrl.dispose();
    _quantidadeCtrl.dispose();
    _custoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  String _vehicleIdFromMap(Map<String, dynamic> v) {
    return (v['id'] ?? v['placa'] ?? '').toString();
  }

  String _vehicleLabel(Map<String, dynamic> v) {
    final placa = (v['placa'] ?? '').toString().trim();
    final tipo = (v['tipo'] ?? '').toString().trim();

    if (placa.isEmpty && tipo.isEmpty) return 'Veículo';
    if (tipo.isEmpty) return placa;
    if (placa.isEmpty) return tipo;
    return '$placa • $tipo';
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final rawVehicles = prefs.getString(_vehiclesKey);

    if (rawVehicles != null && rawVehicles.trim().isNotEmpty) {
      try {
        final list = jsonDecode(rawVehicles) as List;
        _vehicles = list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } catch (_) {
        _vehicles = [];
      }
    } else {
      _vehicles = [];
    }

    if (_vehicles.isNotEmpty) {
      _selectedVehicleId ??= _vehicleIdFromMap(_vehicles.first);
      await _loadRecords();
    } else {
      _selectedVehicleId = null;
      _records = [];
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadRecords() async {
    if (_selectedVehicleId == null || _selectedVehicleId!.trim().isEmpty) {
      _records = [];
      if (mounted) setState(() {});
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_tireKeyPrefix$_selectedVehicleId');

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _records = list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } catch (_) {
        _records = [];
      }
    } else {
      _records = [];
    }

    _records.sort((a, b) {
      final ad = (a['date'] ?? '').toString();
      final bd = (b['date'] ?? '').toString();
      return bd.compareTo(ad);
    });

    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 3, 12, 31),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _neonGreen,
              surface: _surface,
              onSurface: _textMain,
            ),
            dialogBackgroundColor: _background,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _data = picked);
    }
  }

  double _parseMoneyBr(String input) {
    final clean = input.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (clean.isEmpty) return 0.0;

    return double.tryParse(
          clean.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0.0;
  }

  // Formato brasileiro com milhar e 2 decimais
  String _fmt2(double v) {
    final s = v.toStringAsFixed(2);
    final partes = s.split('.');
    final inteiro = partes[0];
    final decimal = partes[1];

    final negativo = inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;

    final buffer = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(numeros[i]);
    }

    return '${negativo ? '-' : ''}${buffer.toString()},$decimal';
  }

  String _fmt(double v) => _fmt2(v);
  String _money(double v) => 'R\$ ${_fmt2(v)}';

  String _formatDate(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final ano = d.year.toString();
    return '$dia/$mes/$ano';
  }

  String _formatDateFromIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return _formatDate(d);
  }

  Future<void> _save() async {
    if (_selectedVehicleId == null || _selectedVehicleId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um veículo.')),
      );
      return;
    }

    final marca = _marcaCtrl.text.trim();
    final modelo = _modeloCtrl.text.trim();
    final fornecedor = _fornecedorCtrl.text.trim();
    final obs = _obsCtrl.text.trim();
    final qtd = int.tryParse(_quantidadeCtrl.text.trim()) ?? 0;
    final custo = _parseMoneyBr(_custoCtrl.text);

    if (marca.isEmpty || qtd <= 0 || custo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha marca, quantidade e valor corretamente.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final record = <String, dynamic>{
      'date': _data.toIso8601String(),
      'marca': marca,
      'modelo': modelo,
      'fornecedor': fornecedor,
      'quantidade': qtd,
      'custo': custo,
      'valorUnitario': custo / qtd,
      'observacao': obs,
    };

    final prefs = await SharedPreferences.getInstance();
    final key = '$_tireKeyPrefix$_selectedVehicleId';

    List<dynamic> list = [];
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      list = jsonDecode(raw) as List;
    }

    list.add(record);
    await prefs.setString(key, jsonEncode(list));

    _marcaCtrl.clear();
    _modeloCtrl.clear();
    _fornecedorCtrl.clear();
    _quantidadeCtrl.clear();
    _custoCtrl.clear();
    _obsCtrl.clear();
    _data = DateTime.now();

    await _loadRecords();

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Pneu salvo!')),
    );
  }

  Future<void> _delete(int index) async {
    if (_selectedVehicleId == null || index < 0 || index >= _records.length) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Apagar registro',
            style: TextStyle(color: _textMain)),
        content: const Text(
          'Deseja realmente apagar este registro de pneu?',
          style: TextStyle(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_tireKeyPrefix$_selectedVehicleId';

    _records.removeAt(index);
    await prefs.setString(key, jsonEncode(_records));

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Registro apagado')),
    );
  }

  double get _total {
    double total = 0.0;
    for (final r in _records) {
      final custo = r['custo'];
      if (custo is num) {
        total += custo.toDouble();
      }
    }
    return total;
  }

  int get _quantidadeTotal {
    int total = 0;
    for (final r in _records) {
      final qtd = r['quantidade'];
      if (qtd is num) {
        total += qtd.toInt();
      }
    }
    return total;
  }

  // ============ WIDGETS DARK NEON ============

  Widget _topCard({
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    final c = color ?? _neonGreen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: c.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: c.withOpacity(0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: c,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Color? iconColor,
  }) {
    final c = iconColor ?? _neonGreen;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _textMuted),
      hintStyle: TextStyle(color: _textMuted.withOpacity(0.5)),
      prefixIcon: icon != null ? Icon(icon, color: c) : null,
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.withOpacity(0.4), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.withOpacity(0.4), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _neonGreen,
          surface: _surface,
          onPrimary: _background,
          onSurface: _textMain,
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final selectedVehicleLabel = _selectedVehicleId == null
        ? '-'
        : _vehicleLabel(
            _vehicles.firstWhere(
              (v) => _vehicleIdFromMap(v) == _selectedVehicleId,
              orElse: () => <String, dynamic>{},
            ),
          );

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _background,
        foregroundColor: _textMain,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_neonGreen, _neonCyan],
          ).createShader(bounds),
          child: const Text(
            'CONTROLE DE PNEUS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: _neonGreen),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _neonGreen),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _neonGreen),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                // ================ HEADER ================
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _neonGreen.withOpacity(0.2),
                        _neonGreen.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: _neonGreen.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: _neonGreen.withOpacity(0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: _neonGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _neonGreen.withOpacity(0.4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.tire_repair_outlined,
                          color: _neonGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Controle de pneus',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _textMain,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Registre compras com detalhes para melhorar dashboard e PDF.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ================ CARDS DE STATUS ================
                Row(
                  children: [
                    Expanded(
                      child: _topCard(
                        icon: Icons.directions_car_outlined,
                        title: 'VEÍCULO',
                        value: selectedVehicleLabel,
                        color: _neonCyan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _topCard(
                        icon: Icons.paid_outlined,
                        title: 'TOTAL VEÍCULO',
                        value: _money(_total),
                        color: _neonPink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _topCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'QTD. TOTAL',
                        value: '$_quantidadeTotal pneus',
                        color: _neonGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _topCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'DATA CADASTRO',
                        value: _formatDate(_data),
                        color: _neonPurple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ================ FORMULÁRIO ================
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _neonGreen.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.add_box_outlined,
                                color: _neonGreen, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Registrar pneus',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _textMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_vehicles.isEmpty)
                          const Text(
                            'Nenhum veículo cadastrado.',
                            style: TextStyle(color: _textMuted),
                          )
                        else
                          Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: _surface,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedVehicleId,
                              isExpanded: true,
                              style: const TextStyle(
                                  color: _textMain, fontSize: 14),
                              dropdownColor: _surface,
                              iconEnabledColor: _neonGreen,
                              items: _vehicles
                                  .map<DropdownMenuItem<String>>((v) {
                                final vehicleId = _vehicleIdFromMap(v);
                                final label = _vehicleLabel(v);

                                return DropdownMenuItem<String>(
                                  value: vehicleId,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                _selectedVehicleId = value;
                                await _loadRecords();
                              },
                              decoration: _inputDecoration(
                                label: 'Veículo',
                                icon: Icons.local_shipping_outlined,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),

                        // Data
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _neonGreen.withOpacity(0.4), width: 1.2),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        color: _neonGreen, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'DATA',
                                            style: TextStyle(
                                              color: _textMuted,
                                              fontSize: 10,
                                              letterSpacing: 1.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(_data),
                                            style: const TextStyle(
                                              color: _textMain,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.edit,
                                        color: _textMuted, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        TextField(
                          controller: _marcaCtrl,
                          style: const TextStyle(
                              color: _textMain, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Marca do pneu',
                            hint: 'Ex: Michelin',
                            icon: Icons.sell_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _modeloCtrl,
                          style: const TextStyle(
                              color: _textMain, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Modelo / medida',
                            hint: 'Ex: 295/80 R22.5',
                            icon: Icons.straighten_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _fornecedorCtrl,
                          style: const TextStyle(
                              color: _textMain, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Fornecedor',
                            hint: 'Ex: Casa dos Pneus',
                            icon: Icons.storefront_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quantidadeCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                    color: _textMain, fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Quantidade',
                                  hint: 'Ex: 2',
                                  icon: Icons.numbers_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _custoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: const TextStyle(
                                    color: _textMain, fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Valor total',
                                  hint: 'Ex: 3.594,52',
                                  icon: Icons.attach_money_outlined,
                                  iconColor: _neonPink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _obsCtrl,
                          maxLines: 2,
                          style: const TextStyle(
                              color: _textMain, fontSize: 14),
                          decoration: _inputDecoration(
                            label: 'Observação',
                            hint: 'Ex: compra emergencial / eixo traseiro',
                            icon: Icons.note_alt_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Botão Salvar
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [_neonGreen, _neonCyan],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _neonGreen.withOpacity(0.35),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (_vehicles.isEmpty || _saving)
                                  ? null
                                  : _save,
                              borderRadius: BorderRadius.circular(14),
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _background,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.save_outlined,
                                              color: _background),
                                          SizedBox(width: 10),
                                          Text(
                                            'SALVAR PNEUS',
                                            style: TextStyle(
                                              color: _background,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              letterSpacing: 0.8,
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
                ),

                const SizedBox(height: 24),

                // ================ HISTÓRICO ================
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history,
                          color: _neonGreen, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Histórico do veículo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _textMain,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _neonGreen.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_records.length}',
                        style: const TextStyle(
                            color: _neonGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_records.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _neonGreen.withOpacity(0.2)),
                    ),
                    child: const Center(
                      child: Text(
                        'Sem registros de pneus para este veículo.',
                        style: TextStyle(color: _textMuted),
                      ),
                    ),
                  )
                else
                  ..._records.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;

                    final marca = (r['marca'] ?? 'Pneu').toString();
                    final modelo = (r['modelo'] ?? '').toString().trim();
                    final fornecedor =
                        (r['fornecedor'] ?? '').toString().trim();
                    final observacao =
                        (r['observacao'] ?? '').toString().trim();
                    final quantidade = r['quantidade'] ?? 0;
                    final custoRec = (r['custo'] is num)
                        ? (r['custo'] as num).toDouble()
                        : 0.0;
                    final unitario = (r['valorUnitario'] is num)
                        ? (r['valorUnitario'] as num).toDouble()
                        : 0.0;
                    final dataStr = _formatDateFromIso(
                        (r['date'] ?? '').toString());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: _neonGreen.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: _neonGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _neonGreen.withOpacity(0.2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.tire_repair_outlined,
                                  color: _neonGreen,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                _neonGreen.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            dataStr,
                                            style: const TextStyle(
                                              color: _neonGreen,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                _neonCyan.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Qtd: $quantidade',
                                            style: const TextStyle(
                                              color: _neonCyan,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      marca,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: _textMain,
                                      ),
                                    ),
                                    if (modelo.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        modelo,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      'Total: ${_money(custoRec)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: _neonGreen,
                                      ),
                                    ),
                                    if (unitario > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Unitário: ${_money(unitario)}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                    if (fornecedor.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Fornecedor: $fornecedor',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                    if (observacao.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Obs.: $observacao',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: _neonPink),
                                onPressed: () => _delete(i),
                                tooltip: 'Apagar',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}