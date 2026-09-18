import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../main.dart';
import '../models/historico_model.dart';
import '../services/supabase_service.dart';
import '../widgets/empty_state.dart';

/// Últimas 100 alterações, da mais recente para a mais antiga.
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _formatoData = DateFormat("dd/MM 'às' HH:mm", 'pt_BR');

  List<HistoricoModel> _registros = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) setState(() => _carregando = true);
    try {
      final dados = await SupabaseService.getHistorico();
      if (!mounted) return;
      setState(() {
        _registros = dados;
        _erro = null;
        _carregando = false;
      });
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
      context.avisoErro(e.mensagem);
    }
  }

  /// "Hoje" / "Ontem" / "12/03" para agrupar visualmente.
  String _rotuloDia(DateTime d) {
    final hoje = DateTime.now();
    final dia = DateTime(d.year, d.month, d.day);
    final refHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final diff = refHoje.difference(dia).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corVerde),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '🕓 Histórico',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _corpo(),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando && _registros.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_registros.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 400,
            child: _erro != null
                ? EmptyState(
                    emoji: '📡',
                    titulo: 'Não deu para carregar',
                    descricao: _erro!,
                    textoBotao: 'Tentar de novo',
                    onBotao: _carregar,
                  )
                : const EmptyState(
                    emoji: '🕓',
                    titulo: 'Nenhuma alteração ainda',
                    descricao:
                        'Tudo que vocês mexerem no estoque aparece aqui.',
                  ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _registros.length,
      itemBuilder: (context, i) {
        final r = _registros[i];
        final anterior = i == 0 ? null : _registros[i - 1];
        final novoDia = anterior == null ||
            _rotuloDia(anterior.createdAt) != _rotuloDia(r.createdAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (novoDia)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 8),
                child: Text(
                  _rotuloDia(r.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withValues(alpha: 0.45),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            _LinhaHistorico(registro: r, hora: _formatoData.format(r.createdAt)),
          ],
        );
      },
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  final HistoricoModel registro;
  final String hora;
  const _LinhaHistorico({required this.registro, required this.hora});

  @override
  Widget build(BuildContext context) {
    final detalhe = registro.detalheQuantidade;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: registro.cor, width: 4),
          top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          right: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: registro.cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(registro.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  registro.itemNome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${registro.usuario} ${registro.acaoTexto}'
                  '${detalhe != null ? " · $detalhe" : ""}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: registro.cor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hora,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.black.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
