import 'package:flutter/material.dart';
import '../services/fuel_price_service.dart';

class FuelPriceWidget extends StatefulWidget {
  const FuelPriceWidget({super.key});

  @override
  State<FuelPriceWidget> createState() => _FuelPriceWidgetState();
}

class _FuelPriceWidgetState extends State<FuelPriceWidget>
    with SingleTickerProviderStateMixin {
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonPink = Color(0xFFFF4D6D);
  static const Color _neonPurple = Color(0xFFB388FF);
  static const Color _surface = Color(0xFF0F1420);
  static const Color _textMain = Color(0xFFE8ECF4);
  static const Color _textMuted = Color(0xFF8A93A8);

  CurrencyData? _data;
  bool _loading = true;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _carregar();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);

    try {
      final data = await FuelPriceService.buscarCotacoes();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      final cache = await FuelPriceService.carregarDoCache();
      if (!mounted) return;
      setState(() {
        _data = cache;
        _loading = false;
      });
    }
  }

  String _fmtBRL(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  String _fmtPct(double v) {
    final abs = v.abs().toStringAsFixed(2).replaceAll('.', ',');
    return '$abs%';
  }

  String _fmtHora(DateTime? d) {
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _currencyItem({
    required String flag,
    required String label,
    required String value,
    required double changePercent,
    required Color corAccent,
  }) {
    final isUp = changePercent >= 0;
    final corSeta = isUp ? _neonGreen : _neonPink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: corAccent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                color: _textMain,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: corSeta,
                size: 16,
              ),
              Text(
                _fmtPct(changePercent),
                style: TextStyle(
                  fontSize: 11,
                  color: corSeta,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _neonCyan.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _neonCyan,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Buscando cotações...',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final d = _data;
    if (d == null || d.dolar == null || d.euro == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _neonPink.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: _neonPink, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sem cotação disponível',
                style: TextStyle(color: _textMain, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _carregar,
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
    }

    final dolar = d.dolar!;
    final euro = d.euro!;
    final offline = d.offline;

    return GestureDetector(
      onTap: _carregar,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _neonCyan.withOpacity(0.1),
              _neonPurple.withOpacity(0.06),
            ],
          ),
          border: Border.all(color: _neonCyan.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: _neonCyan.withOpacity(0.08),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: offline
                            ? _neonPink
                                .withOpacity(0.3 + 0.7 * _pulseController.value)
                            : _neonGreen
                                .withOpacity(0.3 + 0.7 * _pulseController.value),
                        boxShadow: [
                          BoxShadow(
                            color: offline ? _neonPink : _neonGreen,
                            blurRadius: 6 * _pulseController.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offline
                        ? 'Cotação offline — último valor'
                        : 'Cotação ao Vivo • Tempo Real',
                    style: TextStyle(
                      fontSize: 10,
                      color: offline ? _neonPink : _neonCyan,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (d.ultimaAtualizacao != null) ...[
                  Text(
                    _fmtHora(d.ultimaAtualizacao),
                    style: const TextStyle(
                      fontSize: 10,
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.refresh, size: 14, color: _textMuted),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _currencyItem(
                    flag: '🇺🇸',
                    label: 'DÓLAR',
                    value: _fmtBRL(dolar.value),
                    changePercent: dolar.changePercent,
                    corAccent: _neonCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _currencyItem(
                    flag: '🇪🇺',
                    label: 'EURO',
                    value: _fmtBRL(euro.value),
                    changePercent: euro.changePercent,
                    corAccent: _neonPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}