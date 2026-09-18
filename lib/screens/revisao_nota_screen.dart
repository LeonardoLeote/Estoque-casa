import 'package:flutter/material.dart';

import '../constants.dart';
import '../main.dart';
import '../models/item_model.dart';
import '../services/gemini_service.dart';
import '../services/supabase_service.dart';

/// Revisão do que o Gemini leu na nota antes de gravar no estoque.
///
/// A leitura automática erra: importar direto encheria o estoque de lixo.
class RevisaoNotaScreen extends StatefulWidget {
  final List<ProdutoNota> produtos;
  const RevisaoNotaScreen({super.key, required this.produtos});

  @override
  State<RevisaoNotaScreen> createState() => _RevisaoNotaScreenState();
}

class _RevisaoNotaScreenState extends State<RevisaoNotaScreen> {
  bool _importando = false;

  int get _selecionados => widget.produtos.where((p) => p.selecionado).length;

  Future<void> _importar() async {
    final escolhidos = widget.produtos.where((p) => p.selecionado).toList();
    if (escolhidos.isEmpty) return;

    setState(() => _importando = true);
    final agora = DateTime.now();
    final itens = escolhidos
        .map((p) => ItemModel(
              id: '',
              nome: p.nome,
              categoria: p.categoria,
              quantidade: p.quantidade,
              unidade: p.unidade,
              minimo: 0,
              emoji: p.emoji,
              createdAt: agora,
              updatedAt: agora,
            ))
        .toList();

    try {
      final total = await SupabaseService.importarItens(itens);
      if (!mounted) return;
      context.avisoSucesso(
        '$total ${total == 1 ? "item importado" : "itens importados"} da nota!',
      );
      Navigator.pop(context, true);
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      context.avisoErro(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corAzul),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '🧾 Revisar nota',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        actions: [
          TextButton(
            onPressed: _importando
                ? null
                : () {
                    final marcarTodos = _selecionados < widget.produtos.length;
                    setState(() {
                      for (final p in widget.produtos) {
                        p.selecionado = marcarTodos;
                      }
                    });
                  },
            child: Text(
              _selecionados < widget.produtos.length
                  ? 'Marcar todos'
                  : 'Desmarcar',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(AppConstants.corAzul).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Confira antes de importar — a leitura automática pode errar '
              'nomes e quantidades. Todos entram com alerta mínimo 0; ajuste '
              'depois pela tela do item.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final p in widget.produtos)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: CheckboxListTile(
                value: p.selecionado,
                onChanged: _importando
                    ? null
                    : (v) => setState(() => p.selecionado = v ?? false),
                activeColor: const Color(AppConstants.corVerde),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  p.nome,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${p.emoji} ${p.categoria} · '
                  '${ItemModel.formatarNumero(p.quantidade)} ${p.unidade}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed:
                  (_importando || _selecionados == 0) ? null : _importar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(AppConstants.corVerde),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _importando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selecionados == 0
                          ? 'Selecione ao menos um item'
                          : 'Importar $_selecionados '
                              '${_selecionados == 1 ? "item" : "itens"}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
