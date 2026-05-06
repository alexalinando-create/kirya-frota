import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManutencaoScreen extends StatefulWidget {
  const ManutencaoScreen({super.key});

  @override
  State<ManutencaoScreen> createState() => _ManutencaoScreenState();
}

class _ManutencaoScreenState extends State<ManutencaoScreen> {
  // ============ DARK NEON ============
  static const Color _background  = Color(0xFF0A0E1A);
  static const Color _surface     = Color(0xFF0F1420);
  static const Color _surfaceLight= Color(0xFF1A1F2E);
  static const Color _neonCyan    = Color(0xFF00E5FF);
  static const Color _neonPurple  = Color(0xFFB388FF);
  static const Color _neonOrange  = Color(0xFFFF6B35);
  static const Color _neonGreen   = Color(0xFF00FF88);
  static const Color _neonPink    = Color(0xFFFF4D6D);
  static const Color _neonGold    = Color(0xFFE8C547);
  static const Color _textMain    = Color(0xFFE8ECF4);
  static const Color _textMuted   = Color(0xFF8A93A8);

  static const String _vehiclesKey   = 'veiculos_v1';
  static const String _maintKeyPrefix= 'maintenance_records_';

  bool _loadingVehicles = true;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;

  final _descricaoCtrl = TextEditingController();
  final _custoCtrl     = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _records = [];
  bool _loadingRecords = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _custoCtrl.dispose();
    super.dispose();
  }

  String _vehicleIdFromMap(Map<String, dynamic> v) =>
      (v['id'] ?? v['vehicleId'] ?? v['placa'] ?? v['plate'] ?? '').toString();

  String _vehicleLabelFromMap(Map<String, dynamic> v) {
    final placa = (v['placa'] ?? v['plate'] ?? '').toString().trim();
    final tipo  = (v['tipo']  ?? v['type']  ?? '').toString().trim();
    if (placa.isEmpty && tipo.isEmpty) return 'Veiculo';
    if (tipo.isEmpty)  return placa;
    if (placa.isEmpty) return tipo;
    return '$placa - $tipo';
  }

  String _vehicleLabelById(String id) {
    for (final v in _vehicles) {
      if (_vehicleIdFromMap(v) == id) return _vehicleLabelFromMap(v);
    }
    return id;
  }

  Future<void> _loadVehicles() async {
    setState(() => _loadingVehicles = true);
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

    String? firstId;
    if (list.isNotEmpty) {
      firstId = _vehicleIdFromMap(list.first);
      if (firstId.trim().isEmpty) firstId = null;
    }

    setState(() {
      _vehicles          = list;
      _selectedVehicleId = _selectedVehicleId ?? firstId;
      _loadingVehicles   = false;
    });

    if (_selectedVehicleId != null) await _loadRecords(_selectedVehicleId!);
  }

  Future<List<Map<String, dynamic>>> _getRecordsForVehicle(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('$_maintKeyPrefix$vehicleId');
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>()
          .map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRecordsForVehicle(
      String vehicleId, List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_maintKeyPrefix$vehicleId', jsonEncode(records));
  }

  Future<void> _loadRecords(String vehicleId) async {
    setState(() => _loadingRecords = true);
    final recs = await _getRecordsForVehicle(vehicleId);
    recs.sort((a, b) =>
        (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    setState(() {
      _records       = recs;
      _loadingRecords= false;
    });
  }

  double _parseMoney(String s) {
    var t = s.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (t.contains('.') && t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (t.contains(',')) {
      t = t.replaceAll(',', '.');
    }
    return double.tryParse(t) ?? 0.0;
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  DateTime? _tryParseIso(String iso) {
    try { return DateTime.parse(iso); } catch (_) { return null; }
  }

  double get _totalGastoVeiculoAtual {
    double total = 0.0;
    for (final r in _records) {
      if (r['custo'] is num) {
        total += (r['custo'] as num).toDouble();
      } else {
        total += _parseMoney((r['custo'] ?? '').toString());
      }
    }
    return total;
  }

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate:   DateTime(now.year + 2, 12, 31),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _neonOrange,
            onPrimary: Colors.black,
            surface: _surface,
            onSurface: _textMain,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveMaintenance() async {
    final vid = _selectedVehicleId;
    if (vid == null || vid.trim().isEmpty) return;

    final descricao = _descricaoCtrl.text.trim();
    final custo     = _parseMoney(_custoCtrl.text);

    if (custo <= 0) {
      _showError('Informe um custo valido.');
      return;
    }

    final record = <String, dynamic>{
      'date':     _selectedDate.toIso8601String(),
      'descricao':descricao.isEmpty ? 'Manutencao' : descricao,
      'custo':    custo,
    };

    final recs = await _getRecordsForVehicle(vid);
    recs.add(record);
    await _saveRecordsForVehicle(vid, recs);

    _descricaoCtrl.clear();
    _custoCtrl.clear();
    await _loadRecords(vid);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _neonGreen.withOpacity(0.15),
        content: Row(children: const [
          Icon(Icons.check_circle, color: _neonGreen, size: 18),
          SizedBox(width: 8),
          Text('Manutencao salva!',
              style: TextStyle(color: _neonGreen, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _deleteRecord(int index) async {
    final vid = _selectedVehicleId;
    if (vid == null) return;

    final recs   = await _getRecordsForVehicle(vid);
    final target = _records[index];
    recs.removeWhere((e) =>
        (e['date']     ?? '').toString() == (target['date']     ?? '').toString() &&
        (e['descricao']?? '').toString() == (target['descricao']?? '').toString() &&
        (e['custo']    ?? 0).toString()  == (target['custo']    ?? 0).toString());

    await _saveRecordsForVehicle(vid, recs);
    await _loadRecords(vid);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _neonPink.withOpacity(0.15),
        content: Row(children: const [
          Icon(Icons.delete_outline, color: _neonPink, size: 18),
          SizedBox(width: 8),
          Text('Registro removido.',
              style: TextStyle(color: _neonPink, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Row(children: const [
          Icon(Icons.error_outline, color: _neonPink),
          SizedBox(width: 8),
          Text('Atencao', style: TextStyle(color: _textMain)),
        ]),
        content: Text(msg, style: const TextStyle(color: _textMuted)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _neonOrange),
            child: const Text('OK, vou revisar',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ============ WIDGETS ============

  Widget _kpiCard(String label, String value, IconData icon, Color cor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.35), width: 1.2),
        boxShadow: [BoxShadow(color: cor.withOpacity(0.07), blurRadius: 10)],
      ),
      child: Row(children: [
        Container(
          height: 42, width: 42,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cor, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
                fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: _textMain)),
          ],
        )),
      ]),
    );
  }

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required Color cor,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: _textMuted.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: cor, size: 20),
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cor, width: 1.8),
        ),
      ),
    );
  }

  Widget _historyItem(int i) {
    final item     = _records[i];
    final iso      = (item['date'] ?? '').toString();
    final dt       = _tryParseIso(iso);
    final custo    = (item['custo'] is num)
        ? (item['custo'] as num).toDouble() : 0.0;
    final dateLabel= dt == null ? '-' : _fmtDate(dt);
    final descricao= (item['descricao'] ?? 'Manutencao').toString();
    final isLast   = i == _records.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: _neonOrange.withOpacity(0.12)),
        ),
      ),
      child: Row(children: [
        Container(
          height: 44, width: 44,
          decoration: BoxDecoration(
            color: _neonOrange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.build_outlined, color: _neonOrange, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(descricao, style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: _textMain)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 12, color: _textMuted),
              const SizedBox(width: 4),
              Text(dateLabel, style: TextStyle(
                  fontSize: 12, color: _textMuted)),
              const SizedBox(width: 10),
              Icon(Icons.attach_money,
                  size: 12, color: _neonGreen),
              Text('R\$ ${_fmtMoney(custo)}',
                  style: const TextStyle(
                      fontSize: 12, color: _neonGreen,
                      fontWeight: FontWeight.w700)),
            ]),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: _neonPink, size: 22),
          onPressed: () => _showConfirmDelete(i),
        ),
      ]),
    );
  }

  void _showConfirmDelete(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: _neonPink),
          SizedBox(width: 8),
          Text('Remover registro?',
              style: TextStyle(color: _textMain, fontSize: 16)),
        ]),
        content: const Text(
          'Esta acao nao pode ser desfeita.',
          style: TextStyle(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: _textMuted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecord(index);
            },
            style: FilledButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Remover',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUse       = !_loadingVehicles && _vehicles.isNotEmpty;
    final selectedLabel= _selectedVehicleId == null
        ? '-' : _vehicleLabelById(_selectedVehicleId!);

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _neonOrange,
          surface: _surface,
          onPrimary: Colors.black,
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
              colors: [_neonOrange, _neonGold],
            ).createShader(bounds),
            child: const Text('MANUTENCAO',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white)),
          ),
          iconTheme: const IconThemeData(color: _neonOrange),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _loadVehicles,
              icon: const Icon(Icons.refresh, color: _neonOrange),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
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
                    _neonOrange.withOpacity(0.18),
                    _neonGold.withOpacity(0.06),
                  ],
                ),
                border: Border.all(color: _neonOrange.withOpacity(0.35)),
              ),
              child: Row(children: [
                Container(
                  height: 52, width: 52,
                  decoration: BoxDecoration(
                    color: _neonOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.build_circle_outlined,
                      color: _neonOrange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Controle de Manutencao',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900,
                            color: _textMain)),
                    SizedBox(height: 4),
                    Text('Registre servicos e acompanhe o historico.',
                        style: TextStyle(fontSize: 12, color: _textMuted)),
                  ],
                )),
              ]),
            ),

            const SizedBox(height: 14),

            // ===== KPIs =====
            Row(children: [
              Expanded(child: _kpiCard(
                  'Veiculo atual', selectedLabel,
                  Icons.directions_car_outlined, _neonCyan)),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard(
                  'Total gasto', 'R\$ ${_fmtMoney(_totalGastoVeiculoAtual)}',
                  Icons.paid_outlined, _neonGreen)),
            ]),

            const SizedBox(height: 16),

            // ===== FORMULÁRIO =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neonOrange.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                      color: _neonOrange.withOpacity(0.06),
                      blurRadius: 14)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título seção
                  Row(children: const [
                    Icon(Icons.add_circle_outline,
                        color: _neonOrange, size: 20),
                    SizedBox(width: 8),
                    Text('Registrar manutencao',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900,
                            color: _textMain)),
                  ]),
                  const SizedBox(height: 14),

                  // Dropdown veículos
                  if (_loadingVehicles)
                    const Center(child: CircularProgressIndicator(
                        color: _neonOrange))
                  else if (_vehicles.isEmpty)
                    const Text('Nenhum veiculo cadastrado.',
                        style: TextStyle(color: _textMuted))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _neonCyan.withOpacity(0.35)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedVehicleId,
                          dropdownColor: _surfaceLight,
                          iconEnabledColor: _neonCyan,
                          style: const TextStyle(
                              color: _textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          items: _vehicles.map((v) {
                            final id    = _vehicleIdFromMap(v);
                            final label = _vehicleLabelFromMap(v);
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _selectedVehicleId = v);
                            await _loadRecords(v);
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Botão data
                  InkWell(
                    onTap: canUse ? _pickDate : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _neonPurple.withOpacity(0.35)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: _neonPurple, size: 20),
                        const SizedBox(width: 10),
                        Text('Data: ${_fmtDate(_selectedDate)}',
                            style: const TextStyle(
                                color: _textMain,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const Spacer(),
                        const Icon(Icons.edit_outlined,
                            color: _textMuted, size: 16),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Descrição
                  _inputField(
                    ctrl: _descricaoCtrl,
                    label: 'Descricao',
                    hint: 'Ex: troca de oleo, revisao...',
                    icon: Icons.description_outlined,
                    cor: _neonOrange,
                  ),

                  const SizedBox(height: 12),

                  // Custo
                  _inputField(
                    ctrl: _custoCtrl,
                    label: 'Custo (R\$)',
                    hint: 'Ex: 250,00',
                    icon: Icons.attach_money,
                    cor: _neonGreen,
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),

                  // Botão salvar
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [_neonOrange, _neonGold],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: _neonOrange.withOpacity(0.35),
                            blurRadius: 16)
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canUse ? _saveMaintenance : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.save_outlined,
                                  color: Colors.black, size: 20),
                              SizedBox(width: 8),
                              Text('SALVAR MANUTENCAO',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.6)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== HISTÓRICO =====
            Row(children: const [
              Icon(Icons.history, color: _neonOrange, size: 20),
              SizedBox(width: 8),
              Text('Historico do veiculo',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: _textMain)),
            ]),
            const SizedBox(height: 10),

            if (_loadingRecords)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _neonOrange),
              ))
            else if (_selectedVehicleId == null)
              _emptyCard('Selecione um veiculo.')
            else if (_records.isEmpty)
              _emptyCard('Sem manutencoes registradas para $selectedLabel.')
            else
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _neonOrange.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                        color: _neonOrange.withOpacity(0.05),
                        blurRadius: 12)
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _records.length; i++)
                      _historyItem(i),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonOrange.withOpacity(0.2)),
      ),
      child: Text(msg, style: const TextStyle(color: _textMuted)),
    );
  }
}