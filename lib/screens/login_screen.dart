import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _userKey   = 'app_login_user';
  static const String _passKey   = 'app_login_pass';
  static const String _loggedKey = 'app_logged_in';

  static const Color _background   = Color(0xFF0A0E1A);
  static const Color _surface      = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan     = Color(0xFF00E5FF);
  static const Color _neonPurple   = Color(0xFFB388FF);
  static const Color _neonGreen    = Color(0xFF00FF88);
  static const Color _neonPink     = Color(0xFFFF4D6D);
  static const Color _textMain     = Color(0xFFE8ECF4);
  static const Color _textMuted    = Color(0xFF8A93A8);

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading    = true;
  bool _obscure    = true;
  bool _verificado = false;
  bool _primeiroAcesso = false;

  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarSessao() async {
    final prefs     = await SharedPreferences.getInstance();
    final loggedIn  = prefs.getBool(_loggedKey) ?? false;
    final savedUser = prefs.getString(_userKey);

    if (loggedIn && savedUser != null && savedUser.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    final isPrimeiro = savedUser == null || savedUser.isEmpty;

    if (mounted) setState(() {
      _loading       = false;
      _verificado    = true;
      _primeiroAcesso = isPrimeiro;
    });
  }

  Future<void> _entrar() async {
    if (_loading) return;

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _surface,
          content: Row(children: const [
            Icon(Icons.warning_amber_rounded, color: _neonPink, size: 18),
            SizedBox(width: 8),
            Text('Preencha usuario e senha.',
                style: TextStyle(color: _textMain)),
          ]),
        ),
      );
      return;
    }

    if (_primeiroAcesso && pass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _surface,
          content: Row(children: const [
            Icon(Icons.warning_amber_rounded, color: _neonPink, size: 18),
            SizedBox(width: 8),
            Text('A senha deve ter pelo menos 4 caracteres.',
                style: TextStyle(color: _textMain)),
          ]),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs     = await SharedPreferences.getInstance();
      final savedUser = prefs.getString(_userKey);
      final savedPass = prefs.getString(_passKey);

      // Primeiro acesso — salva as credenciais e entra
      if (savedUser == null || savedPass == null) {
        await prefs.setString(_userKey, user);
        await prefs.setString(_passKey, pass);
        await prefs.setBool(_loggedKey, true);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      // Login correto
      if (user == savedUser && pass == savedPass) {
        await prefs.setBool(_loggedKey, true);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _surface,
            content: Row(children: const [
              Icon(Icons.lock_outlined, color: _neonPink, size: 18),
              SizedBox(width: 8),
              Text('Usuario ou senha incorretos.',
                  style: TextStyle(color: _neonPink,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_verificado) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: CircularProgressIndicator(color: _neonCyan),
        ),
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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ===== LOGO =====
                    Center(
                      child: Container(
                        height: 100, width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: _neonCyan.withOpacity(0.25),
                                blurRadius: 24),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== TÍTULO =====
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [_neonCyan, _neonPurple],
                      ).createShader(bounds),
                      child: const Text(
                        'KIRYA FROTA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _primeiroAcesso
                          ? 'Crie seu acesso agora'
                          : 'Acesso restrito',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: _textMuted),
                    ),

                    const SizedBox(height: 32),

                    // ===== CARD LOGIN =====
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _neonCyan.withOpacity(0.25), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                              color: _neonCyan.withOpacity(0.07),
                              blurRadius: 18),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // Campo usuário
                          TextField(
                            controller: _userCtrl,
                            style: const TextStyle(color: _textMain),
                            onSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              labelStyle: const TextStyle(
                                  color: _textMuted, fontSize: 13),
                              prefixIcon: const Icon(
                                  Icons.person_outline, color: _neonCyan),
                              filled: true,
                              fillColor: _surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _neonCyan.withOpacity(0.3))),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _neonCyan.withOpacity(0.3))),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: _neonCyan, width: 2)),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Campo senha
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: const TextStyle(color: _textMain),
                            onSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              labelStyle: const TextStyle(
                                  color: _textMuted, fontSize: 13),
                              prefixIcon: const Icon(
                                  Icons.password, color: _neonPurple),
                              filled: true,
                              fillColor: _surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _neonPurple.withOpacity(0.3))),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _neonPurple.withOpacity(0.3))),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: _neonPurple, width: 2)),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _textMuted,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Botão entrar
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [_neonCyan, _neonPurple],
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: _neonCyan.withOpacity(0.35),
                                    blurRadius: 16),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _loading ? null : _entrar,
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _background))
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.login,
                                                color: _background, size: 20),
                                            const SizedBox(width: 10),
                                            Text(
                                              _primeiroAcesso
                                                  ? 'CRIAR ACESSO'
                                                  : 'ENTRAR',
                                              style: const TextStyle(
                                                color: _background,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                letterSpacing: 1.0,
                                              )),
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

                    // Dica
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _neonCyan.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _neonCyan.withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            color: _neonCyan, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _primeiroAcesso
                                ? 'Primeiro acesso: escolha seu usuario e senha. Eles serao salvos para os proximos acessos.'
                                : 'Use o usuario e senha cadastrados no primeiro acesso.',
                            style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11.5,
                                height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}