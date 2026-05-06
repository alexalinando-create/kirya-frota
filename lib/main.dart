import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/abastecimento_km_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/manutencao_screen.dart';
import 'screens/pneus_screen.dart';
import 'screens/tanque_screen.dart';
import 'screens/relatorio_mensal_pdf_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _autoImportarDadosIniciais();
  runApp(const MyApp());
}

const String kVehiclesKey = 'veiculos_v1';

Future<void> _autoImportarDadosIniciais() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kVehiclesKey);
    if (raw != null && raw.trim().isNotEmpty && raw.trim() != '[]') {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) return;
      } catch (_) {}
    }
    final jsonStr = await rootBundle.loadString('assets/dados_iniciais.json');
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) return;
    final dados = decoded['dados'];
    if (dados is! Map<String, dynamic>) return;
    int restaurados = 0;
    for (final entry in dados.entries) {
      final key   = entry.key;
      final info  = entry.value;
      if (info is! Map) continue;
      final tipo  = info['tipo']?.toString();
      final valor = info['valor'];
      try {
        if (tipo == 'bool' && valor is bool) {
          await prefs.setBool(key, valor); restaurados++;
        } else if (tipo == 'int' && valor is num) {
          await prefs.setInt(key, valor.toInt()); restaurados++;
        } else if (tipo == 'double' && valor is num) {
          await prefs.setDouble(key, valor.toDouble()); restaurados++;
        } else if (tipo == 'String' && valor is String) {
          await prefs.setString(key, valor); restaurados++;
        } else if (tipo == 'List<String>' && valor is List) {
          await prefs.setStringList(
              key, valor.map((e) => e.toString()).toList());
          restaurados++;
        }
      } catch (_) {}
    }
    await prefs.setBool('dados_iniciais_carregados', true);
    debugPrint('✅ $restaurados chaves restauradas do dados_iniciais.json');
  } catch (e) {
    debugPrint('⚠️ Erro ao auto-importar dados iniciais: $e');
  }
}

const Color _kBackground   = Color(0xFF0A0E1A);
const Color _kSurface      = Color(0xFF0F1420);
const Color _kSurfaceLight = Color(0xFF1A1F2E);
const Color _kNeonCyan     = Color(0xFF00E5FF);
const Color _kNeonPurple   = Color(0xFFB388FF);
const Color _kNeonOrange   = Color(0xFFFF6B35);
const Color _kNeonGreen    = Color(0xFF00FF88);
const Color _kNeonPink     = Color(0xFFFF4D6D);
const Color _kNeonBlue     = Color(0xFF3AA0FF);
const Color _kNeonGold     = Color(0xFFE8C547);
const Color _kTextMain     = Color(0xFFE8ECF4);
const Color _kTextMuted    = Color(0xFF8A93A8);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Frota',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBackground,
        colorScheme: const ColorScheme.dark(
          primary: _kNeonCyan,
          surface: _kSurface,
          onPrimary: _kBackground,
          onSurface: _kTextMain,
        ),
      ),
      home: const LoginScreen(),
      routes: {
        '/login':            (_) => const LoginScreen(),
        '/home':             (_) => const HomePage(),
        '/abastecimento_km': (_) => AbastecimentoKmScreen(),
        '/dashboard':        (_) => const DashboardScreen(),
        '/manutencao':       (_) => const ManutencaoScreen(),
        '/pneus':            (_) => const PneusScreen(),
        '/tanque':           (_) => TanqueScreen(),
        '/relatorio_pdf':    (_) => const RelatorioMensalPdfScreen(),
        '/veiculos':         (_) => const GerenciarVeiculosScreen(),
        '/settings':         (_) => const SettingsScreen(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _dolarKey   = 'currency_dolar_v1';
  static const String _euroKey    = 'currency_euro_v1';
  static const String _companyKey = 'company_name';

  double? _dolar;
  double? _euro;
  String  _empresa         = '';
  bool    _loadingCotacoes = true;
  Timer?  _refreshTimer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _refreshTimer = Timer.periodic(
        const Duration(minutes: 30), (_) => _carregarDados());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recarregarEmpresa();
  }

  Future<void> _recarregarEmpresa() async {
    final prefs   = await SharedPreferences.getInstance();
    final empresa = prefs.getString(_companyKey)?.trim() ?? '';
    if (mounted && empresa != _empresa) setState(() => _empresa = empresa);
  }

  Future<void> _carregarDados() async {
    setState(() => _loadingCotacoes = true);
    final prefs = await SharedPreferences.getInstance();
    _empresa = prefs.getString(_companyKey)?.trim() ?? '';
    final dCache = prefs.getDouble(_dolarKey);
    final eCache = prefs.getDouble(_euroKey);
    if (dCache != null) _dolar = dCache;
    if (eCache != null) _euro  = eCache;
    if (mounted) setState(() {});
    try {
      final response = await http
          .get(Uri.parse(
              'https://economia.awesomeapi.com.br/last/USD-BRL,EUR-BRL'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usd  = data['USDBRL'];
        final eur  = data['EURBRL'];
        if (usd?['bid'] != null) {
          final v = double.tryParse(usd['bid'].toString());
          if (v != null && v > 0) {
            _dolar = v;
            await prefs.setDouble(_dolarKey, v);
          }
        }
        if (eur?['bid'] != null) {
          final v = double.tryParse(eur['bid'].toString());
          if (v != null && v > 0) {
            _euro = v;
            await prefs.setDouble(_euroKey, v);
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCotacoes = false);
  }

  String _money(double? v) {
    if (v == null) return '--';
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Widget _cotacaoCard({
    required String label,
    required IconData icon,
    required double? valor,
    required Color cor,
    required String moeda,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kSurface,
        border: Border.all(color: cor.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: cor.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: cor, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: TextStyle(color: cor, fontSize: 10.5,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(width: 4),
              Text(moeda, style: const TextStyle(color: _kTextMuted,
                  fontSize: 9, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Text(_money(valor), style: const TextStyle(color: _kTextMain,
                fontSize: 16, fontWeight: FontWeight.w900)),
          ])),
        if (_loadingCotacoes && valor == null)
          const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _kTextMuted)),
      ]),
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _kSurface,
          border: Border.all(color: cor.withOpacity(0.4), width: 1.2),
          boxShadow: [BoxShadow(color: cor.withOpacity(0.12), blurRadius: 14)]),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: cor.withOpacity(0.3), blurRadius: 8)]),
                child: Icon(icon, color: cor, size: 22)),
              const Spacer(),
              Text(title, style: const TextStyle(color: _kTextMain,
                  fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11,
                  color: _kTextMuted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tituloEmpresa = _empresa.isEmpty ? 'Controle central' : _empresa;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        foregroundColor: _kTextMain,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_kNeonCyan, _kNeonPurple]).createShader(bounds),
          child: const Text('GESTOR DE FROTA',
            style: TextStyle(fontWeight: FontWeight.w900,
                letterSpacing: 1.2, color: Colors.white))),
        actions: [
          IconButton(
            tooltip: 'Atualizar cotacoes',
            onPressed: _loadingCotacoes ? null : _carregarDados,
            icon: const Icon(Icons.refresh, color: _kNeonCyan)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        children: [

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kNeonCyan.withOpacity(0.18),
                  _kNeonPurple.withOpacity(0.10)]),
              border: Border.all(color: _kNeonCyan.withOpacity(0.4)),
              boxShadow: [BoxShadow(
                  color: _kNeonCyan.withOpacity(0.12), blurRadius: 18)]),
            child: Row(children: [
              Container(
                height: 64, width: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kNeonCyan.withOpacity(0.3))),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/icon.png', fit: BoxFit.cover)))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tituloEmpresa,
                    style: const TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w900, color: _kTextMain),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  const Text(
                    'Gestao completa de combustivel, manutencao e relatorios.',
                    style: TextStyle(fontSize: 12, color: _kTextMuted)),
                ])),
            ]),
          ),

          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: _cotacaoCard(
              label: 'DOLAR', icon: Icons.attach_money,
              valor: _dolar, cor: _kNeonGreen, moeda: 'USD')),
            const SizedBox(width: 10),
            Expanded(child: _cotacaoCard(
              label: 'EURO', icon: Icons.euro,
              valor: _euro, cor: _kNeonBlue, moeda: 'EUR')),
          ]),

          const SizedBox(height: 18),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('MODULOS', style: TextStyle(
                color: _kNeonCyan, fontSize: 12,
                fontWeight: FontWeight.w900, letterSpacing: 1.5))),

          LayoutBuilder(builder: (context, constraints) {
            final w     = constraints.maxWidth;
            final cardW = (w - 12) / 2;
            return Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.local_gas_station_outlined,
                    title: 'Abastecimento',
                    subtitle: 'Calcular e salvar por KM',
                    cor: _kNeonCyan,
                    onTap: () => Navigator.pushNamed(
                        context, '/abastecimento_km'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    subtitle: 'Resumo e ranking',
                    cor: _kNeonPurple,
                    onTap: () => Navigator.pushNamed(context, '/dashboard'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.build_outlined,
                    title: 'Manutencao',
                    subtitle: 'Custos e historico',
                    cor: _kNeonOrange,
                    onTap: () => Navigator.pushNamed(context, '/manutencao'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.tire_repair_outlined,
                    title: 'Pneus',
                    subtitle: 'Controle e historico',
                    cor: _kNeonGold,
                    onTap: () => Navigator.pushNamed(context, '/pneus'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.picture_as_pdf_outlined,
                    title: 'Relatorio PDF',
                    subtitle: 'Gerar e compartilhar',
                    cor: _kNeonPink,
                    onTap: () => Navigator.pushNamed(
                        context, '/relatorio_pdf'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.directions_car_filled_outlined,
                    title: 'Veiculos',
                    subtitle: 'Cadastrar e gerenciar',
                    cor: _kNeonGreen,
                    onTap: () => Navigator.pushNamed(context, '/veiculos'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.propane_tank_outlined,
                    title: 'Tanque',
                    subtitle: 'Diesel estacionario',
                    cor: _kNeonGold,
                    onTap: () => Navigator.pushNamed(context, '/tanque'))),
                SizedBox(width: cardW, height: 150,
                  child: _moduleCard(
                    icon: Icons.settings_outlined,
                    title: 'Configuracoes',
                    subtitle: 'Empresa, login e backup',
                    cor: _kNeonBlue,
                    onTap: () => Navigator.pushNamed(context, '/settings'))),
              ],
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============ GERENCIAR VEÍCULOS ============

class GerenciarVeiculosScreen extends StatefulWidget {
  const GerenciarVeiculosScreen({super.key});

  @override
  State<GerenciarVeiculosScreen> createState() =>
      _GerenciarVeiculosScreenState();
}

class _GerenciarVeiculosScreenState extends State<GerenciarVeiculosScreen> {
  final _placaCtrl = TextEditingController();
  final _tipoCtrl  = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _veiculos = [];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _tipoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(kVehiclesKey);
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
    if (!mounted) return;
    setState(() { _veiculos = list; _loading = false; });
  }

  Future<void> _save(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kVehiclesKey, jsonEncode(list));
  }

  String _normPlaca(String s) => s.trim().toUpperCase();

  bool _placaExists(String placa) {
    final p = _normPlaca(placa);
    for (final v in _veiculos) {
      final vp = (v['placa'] ?? v['plate'] ?? '')
          .toString().trim().toUpperCase();
      if (vp == p && vp.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _addVehicle() async {
    final placa = _normPlaca(_placaCtrl.text);
    final tipo  = _tipoCtrl.text.trim();
    if (placa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a placa.')));
      return;
    }
    if (_placaExists(placa)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Essa placa ja esta cadastrada.')));
      return;
    }
    final id   = DateTime.now().millisecondsSinceEpoch.toString();
    final novo = <String, dynamic>{'id': id, 'placa': placa, 'tipo': tipo};
    await _save([..._veiculos, novo]);
    _placaCtrl.clear();
    _tipoCtrl.clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: _kSurface,
        content: Text('Veiculo cadastrado!',
            style: TextStyle(color: _kTextMain))));
  }

  Future<void> _deleteByPlaca(String placa) async {
    final p      = _normPlaca(placa);
    if (p.isEmpty) return;
    final before = _veiculos.length;
    final list   = _veiculos.where((v) {
      final vp = (v['placa'] ?? v['plate'] ?? '')
          .toString().trim().toUpperCase();
      return vp != p;
    }).toList();
    if (list.length == before) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Placa nao encontrada.')));
      return;
    }
    await _save(list);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: _kSurface,
        content: Text('Veiculo removido.',
            style: TextStyle(color: _kTextMain))));
  }

  Future<void> _confirmDelete(String placa) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('Apagar veiculo',
            style: TextStyle(color: _kTextMain)),
        content: Text(
          'Confirma apagar o veiculo $placa?\n\nIsso remove apenas o cadastro.',
          style: const TextStyle(color: _kTextMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _kNeonCyan))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kNeonPink),
            child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) await _deleteByPlaca(placa);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        foregroundColor: _kTextMain,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_kNeonGreen, _kNeonCyan]).createShader(bounds),
          child: const Text('VEICULOS',
            style: TextStyle(fontWeight: FontWeight.w900,
                letterSpacing: 1.0, color: Colors.white))),
        iconTheme: const IconThemeData(color: _kNeonGreen),
        actions: [
          IconButton(tooltip: 'Atualizar', onPressed: _load,
              icon: const Icon(Icons.refresh, color: _kNeonGreen))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _kSurface,
              border: Border.all(color: _kNeonGreen.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: const [
                  Icon(Icons.add_circle_outline, color: _kNeonGreen, size: 22),
                  SizedBox(width: 8),
                  Text('Cadastrar veiculo', style: TextStyle(
                      color: _kTextMain, fontSize: 15,
                      fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _placaCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: _kTextMain),
                  decoration: InputDecoration(
                    labelText: 'Placa',
                    labelStyle: const TextStyle(color: _kTextMuted),
                    hintText: 'Ex: PMH5400',
                    hintStyle: TextStyle(color: _kTextMuted.withOpacity(0.5)),
                    filled: true, fillColor: _kSurfaceLight,
                    prefixIcon: const Icon(Icons.directions_car,
                        color: _kNeonGreen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _kNeonGreen.withOpacity(0.3))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _kNeonGreen.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _kNeonGreen, width: 2)))),
                const SizedBox(height: 10),
                TextField(
                  controller: _tipoCtrl,
                  style: const TextStyle(color: _kTextMain),
                  decoration: InputDecoration(
                    labelText: 'Tipo (opcional)',
                    labelStyle: const TextStyle(color: _kTextMuted),
                    hintText: 'Ex: caminhao, bitruck...',
                    hintStyle: TextStyle(color: _kTextMuted.withOpacity(0.5)),
                    filled: true, fillColor: _kSurfaceLight,
                    prefixIcon: const Icon(Icons.category, color: _kNeonGreen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _kNeonGreen.withOpacity(0.3))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _kNeonGreen.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _kNeonGreen, width: 2)))),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                        colors: [_kNeonGreen, _kNeonCyan])),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _addVehicle,
                      borderRadius: BorderRadius.circular(12),
                      child: const Center(child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: _kBackground),
                          SizedBox(width: 8),
                          Text('CADASTRAR', style: TextStyle(
                              color: _kBackground, fontWeight: FontWeight.w900,
                              fontSize: 14, letterSpacing: 0.8)),
                        ])))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(children: [
            const Icon(Icons.list_alt, color: _kNeonGreen),
            const SizedBox(width: 8),
            const Text('Cadastrados', style: TextStyle(
                color: _kTextMain, fontSize: 15, fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kNeonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kNeonGreen.withOpacity(0.3))),
              child: Text(_loading ? '...' : '${_veiculos.length}',
                style: const TextStyle(color: _kNeonGreen,
                    fontWeight: FontWeight.w800, fontSize: 12))),
          ]),
          const SizedBox(height: 10),

          if (_loading)
            const Padding(padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator(
                  color: _kNeonGreen)))
          else if (_veiculos.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kTextMuted.withOpacity(0.2))),
              child: const Center(child: Text('Nenhum veiculo cadastrado.',
                  style: TextStyle(color: _kTextMuted))))
          else
            ..._veiculos.map((v) {
              final placa = (v['placa'] ?? '').toString();
              final tipo  = (v['tipo']  ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kNeonGreen.withOpacity(0.2))),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _kNeonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.directions_car,
                        color: _kNeonGreen, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(placa, style: const TextStyle(
                          color: _kTextMain, fontWeight: FontWeight.w900,
                          fontSize: 14)),
                      if (tipo.isNotEmpty)
                        Text(tipo, style: const TextStyle(
                            color: _kTextMuted, fontSize: 12)),
                    ])),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _kNeonPink),
                    onPressed: () => _confirmDelete(placa),
                    tooltip: 'Apagar'),
                ]),
              );
            }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}