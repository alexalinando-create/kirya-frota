import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _companyNameKey = 'company_name';
  static const String _userKey        = 'app_login_user';
  static const String _passKey        = 'app_login_pass';
  static const String _loggedKey      = 'app_logged_in';

  static const Color _background   = Color(0xFF0A0E1A);
  static const Color _surface      = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan     = Color(0xFF00E5FF);
  static const Color _neonPurple   = Color(0xFFB388FF);
  static const Color _neonOrange   = Color(0xFFFF6B35);
  static const Color _neonGreen    = Color(0xFF00FF88);
  static const Color _neonPink     = Color(0xFFFF4D6D);
  static const Color _textMain     = Color(0xFFE8ECF4);
  static const Color _textMuted    = Color(0xFF8A93A8);

  final _empresaCtrl = TextEditingController();
  final _userCtrl    = TextEditingController();
  final _passCtrl    = TextEditingController();

  bool _loading           = true;
  bool _processandoBackup = false;
  String? _ultimoBackupAuto;
  List<BackupInfo> _backupsLocais = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empresaCtrl.text = prefs.getString(_companyNameKey) ?? '';
      _userCtrl.text    = prefs.getString(_userKey) ?? '';
      _passCtrl.text    = prefs.getString(_passKey) ?? '';
      _ultimoBackupAuto = prefs.getString('ultimo_backup_auto');
      _loading          = false;
    });
    _carregarBackupsLocais();
  }

  Future<void> _carregarBackupsLocais() async {
    final backups = await BackupService.listarBackupsAutomaticos();
    if (!mounted) return;
    setState(() => _backupsLocais = backups);
  }

  Future<void> _saveCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyNameKey, _empresaCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _surface,
        content: Text('Nome da empresa salvo',
            style: TextStyle(color: _textMain)),
      ),
    );
  }

  Future<void> _saveLogin() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha usuario e senha')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _userCtrl.text.trim());
    await prefs.setString(_passKey, _passCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _surface,
        content: Text('Login atualizado',
            style: TextStyle(color: _textMain)),
      ),
    );
  }

  Future<void> _sair() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Row(children: [
          Icon(Icons.logout, color: _neonPink),
          SizedBox(width: 8),
          Text('Sair do app', style: TextStyle(color: _textMain)),
        ]),
        content: const Text(
          'Deseja sair? Voce precisara fazer login novamente.',
          style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _neonCyan))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Sair')),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedKey, false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _exportarBackup() async {
    setState(() => _processandoBackup = true);
    final ok = await BackupService.exportarBackup();
    if (!mounted) return;
    setState(() => _processandoBackup = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: _surface,
          content: Text('Backup exportado',
              style: TextStyle(color: _textMain))));
    } else {
      _showError('Erro', 'Nao foi possivel exportar o backup.');
    }
  }

  Future<void> _importarBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: _neonOrange),
          SizedBox(width: 8),
          Text('Atencao', style: TextStyle(color: _textMain)),
        ]),
        content: const Text(
          'Importar um backup vai SOBRESCREVER os dados atuais.\n\nDeseja continuar?',
          style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _neonCyan))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _neonOrange),
            child: const Text('Importar')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _processandoBackup = true);
    final result = await BackupService.importarBackup();
    if (!mounted) return;
    setState(() => _processandoBackup = false);
    if (result.sucesso) {
      await _loadSettings();
      _showSuccess(result.mensagem,
        'Total restaurado: ${result.totalRestaurados ?? 0}\nReinicie o app para ver todas as mudancas.');
    } else {
      _showError('Erro', result.mensagem);
    }
  }

  Future<void> _backupLocalAgora() async {
    setState(() => _processandoBackup = true);
    final caminho = await BackupService.fazerBackupAutomatico();
    if (!mounted) return;
    setState(() => _processandoBackup = false);
    await _loadSettings();
    if (caminho != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: _surface,
          content: Text('Backup local criado',
              style: TextStyle(color: _textMain))));
    } else {
      _showError('Erro', 'Nao foi possivel criar o backup local.');
    }
  }

  Future<void> _restaurarBackupLocal(BackupInfo info) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Row(children: [
          Icon(Icons.restore, color: _neonOrange),
          SizedBox(width: 8),
          Text('Restaurar backup', style: TextStyle(color: _textMain)),
        ]),
        content: Text(
          'Deseja restaurar o backup de ${_fmtData(info.dataModificacao)}?\n\nIsso vai SOBRESCREVER os dados atuais.',
          style: const TextStyle(color: _textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _neonCyan))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _neonOrange),
            child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _processandoBackup = true);
    final result = await BackupService.restaurarBackupAutomatico(info.caminho);
    if (!mounted) return;
    setState(() => _processandoBackup = false);
    if (result.sucesso) {
      await _loadSettings();
      _showSuccess(result.mensagem,
        'Total restaurado: ${result.totalRestaurados ?? 0}\nReinicie o app para ver todas as mudancas.');
    } else {
      _showError('Erro', result.mensagem);
    }
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

  void _showSuccess(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Row(children: [
          const Icon(Icons.check_circle_outline, color: _neonGreen),
          const SizedBox(width: 8),
          Text(titulo, style: const TextStyle(color: _textMain)),
        ]),
        content: Text(msg, style: const TextStyle(color: _textMuted)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _neonGreen),
            child: const Text('OK')),
        ],
      ),
    );
  }

  String _fmtData(DateTime d) {
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
        '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  String _fmtDataCurta(String? iso) {
    if (iso == null) return 'Nunca';
    try { return _fmtData(DateTime.parse(iso)); } catch (_) { return 'Nunca'; }
  }

  Widget _section({
    required String titulo,
    required IconData icon,
    required Color cor,
    required Widget child,
    String? subtitulo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: cor.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: cor, size: 22),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(
                color: _textMain, fontSize: 15,
                fontWeight: FontWeight.w900)),
          ]),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(subtitulo,
                  style: const TextStyle(color: _textMuted, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Color? cor,
  }) {
    final c = cor ?? _neonCyan;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
      filled: true,
      fillColor: _surfaceLight,
      prefixIcon: Icon(icon, color: c, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.withOpacity(0.3), width: 1.2)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.withOpacity(0.3), width: 1.2)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: 2)),
    );
  }

  Widget _buttonGradient({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required List<Color> cores,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: cores),
        boxShadow: [BoxShadow(
            color: cores.first.withOpacity(0.3), blurRadius: 12)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _background, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                  color: _background, fontWeight: FontWeight.w900,
                  fontSize: 13, letterSpacing: 0.5)),
            ],
          )),
        ),
      ),
    );
  }

  Widget _buttonOutline({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required Color cor,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: cor, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                  color: cor, fontWeight: FontWeight.w900,
                  fontSize: 13, letterSpacing: 0.5)),
            ],
          )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Theme(
        data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _background),
        child: const Scaffold(
          backgroundColor: _background,
          body: Center(child: CircularProgressIndicator(color: _neonCyan))),
      );
    }

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _neonCyan,
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
              colors: [_neonCyan, _neonPurple],
            ).createShader(bounds),
            child: const Text('CONFIGURACOES',
              style: TextStyle(fontWeight: FontWeight.w900,
                  letterSpacing: 1.0, color: Colors.white)),
          ),
          iconTheme: const IconThemeData(color: _neonCyan),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ===== EMPRESA =====
            _section(
              titulo: 'Empresa',
              icon: Icons.business,
              cor: _neonCyan,
              subtitulo: 'Aparece no cabecalho do PDF e voucher',
              child: Column(children: [
                TextField(
                  controller: _empresaCtrl,
                  style: const TextStyle(color: _textMain),
                  decoration: _inputDeco(
                      label: 'Nome da empresa', icon: Icons.business),
                ),
                const SizedBox(height: 12),
                _buttonGradient(
                  label: 'SALVAR EMPRESA',
                  icon: Icons.save,
                  onTap: _saveCompanyName,
                  cores: const [_neonCyan, _neonPurple]),
              ]),
            ),

            // ===== LOGIN =====
            _section(
              titulo: 'Login',
              icon: Icons.lock_outline,
              cor: _neonGreen,
              subtitulo: 'Usuario e senha de acesso ao app',
              child: Column(children: [
                TextField(
                  controller: _userCtrl,
                  style: const TextStyle(color: _textMain),
                  decoration: _inputDeco(
                      label: 'Usuario',
                      icon: Icons.person_outline,
                      cor: _neonGreen),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  style: const TextStyle(color: _textMain),
                  obscureText: true,
                  decoration: _inputDeco(
                      label: 'Senha',
                      icon: Icons.password,
                      cor: _neonGreen),
                ),
                const SizedBox(height: 12),
                _buttonGradient(
                  label: 'SALVAR LOGIN',
                  icon: Icons.save,
                  onTap: _saveLogin,
                  cores: const [_neonGreen, _neonCyan]),
              ]),
            ),

            // ===== BACKUP =====
            _section(
              titulo: 'Backup e Restauracao',
              icon: Icons.cloud_sync_outlined,
              cor: _neonOrange,
              subtitulo:
                  'Ultimo backup automatico: ${_fmtDataCurta(_ultimoBackupAuto)}',
              child: Column(children: [
                _buttonGradient(
                  label: _processandoBackup
                      ? 'PROCESSANDO...' : 'EXPORTAR BACKUP',
                  icon: Icons.upload,
                  onTap: _processandoBackup ? null : _exportarBackup,
                  cores: const [_neonOrange, _neonPink]),
                const SizedBox(height: 8),
                _buttonOutline(
                  label: _processandoBackup
                      ? 'PROCESSANDO...' : 'IMPORTAR BACKUP',
                  icon: Icons.download,
                  onTap: _processandoBackup ? null : _importarBackup,
                  cor: _neonCyan),
                const SizedBox(height: 8),
                _buttonOutline(
                  label: _processandoBackup
                      ? 'PROCESSANDO...' : 'BACKUP LOCAL AGORA',
                  icon: Icons.save_alt,
                  onTap: _processandoBackup ? null : _backupLocalAgora,
                  cor: _neonGreen),
                if (_backupsLocais.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _neonOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _neonOrange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BACKUPS LOCAIS RECENTES',
                          style: TextStyle(color: _neonOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 11, letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        ..._backupsLocais.take(5).map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _restaurarBackupLocal(b),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.restore,
                                      color: _neonOrange, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_fmtData(b.dataModificacao),
                                        style: const TextStyle(
                                            color: _textMain,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                      Text(b.tamanhoFormatado,
                                        style: const TextStyle(
                                            color: _textMuted,
                                            fontSize: 10)),
                                    ],
                                  )),
                                  const Icon(Icons.chevron_right,
                                      color: _textMuted, size: 18),
                                ]),
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ]),
            ),

            // ===== INFO =====
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _textMuted.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: _textMuted, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Kirya Frota v1.0\nDados salvos localmente no celular.',
                  style: TextStyle(
                      color: _textMuted, fontSize: 12, height: 1.4))),
              ]),
            ),

            const SizedBox(height: 16),

            // ===== BOTÃO SAIR =====
            _buttonOutline(
              label: 'SAIR DO APP',
              icon: Icons.logout,
              onTap: _sair,
              cor: _neonPink),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}