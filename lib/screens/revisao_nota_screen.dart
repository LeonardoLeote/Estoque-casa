import 'package:flutter/material.dart';

import '../constants.dart';
import '../main.dart';
import '../models/item_model.dart';
import '../services/gemini_service.dart';
import '../services/supabase_service.dart';
import '../widgets/editor_produto_nota.dart';

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

  Future<void> _editar(ProdutoNota produto) async {
    final mudou = await EditorProdutoNota.abrir(context, produto);
    if (mudou && mounted) {
      // O editor altera o produto no lugar; só falta redesenhar a lista.
      setState(() => produto.selecionado = true);
    }
  }

  /// Soma preço × quantidade do que está marcado. Ignora os sem preço —
  /// por isso é "parcial" e não um total da nota.
  double get _totalSelecionado => widget.produtos
      .where((p) => p.selecionado && p.preco != null)
      .fold(0.0, (soma, p) => soma + p.preco! * p.quantidade);

  bool get _algumSemPreco =>
      widget.produtos.any((p) => p.selecionado && p.preco == null);

  Future<void> _importar() async {
    final escolhidos = widget.produtos.where((p) => p.selecionado).toList();
    if (escolhidos.isEmpty) return;

    setState(() => _importando = true);
    final agora = DateTime.now();
    final itens = escolhidos
        .map(
          (p) => ItemModel(
            id: '',
            nome: p.nome,
            categoria: p.categoria,
            quantidade: p.quantidade,
            unidade: p.unidade,
            minimo: 0,
            emoji: p.emoji,
            preco: p.preco,
            createdAt: agora,
            updatedAt: agora,
          ),
        )
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
              'Toque em um produto para corrigir nome, quantidade, categoria '
              'ou preço antes de importar — a leitura automática erra. Todos '
              'entram com alerta mínimo 0; ajuste depois pela tela do item.',
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              clipBehavior: Clip.antiAlias,
              // O ListTile pinta fundo e ondulação no Material mais próximo:
              // sem este, a cor do Container esconderia o toque.
              child: Material(
                color: Colors.white,
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
                    '${ItemModel.formatarNumero(p.quantidade)} ${p.unidade}'
                    '${p.preco == null ? "" : " · ${ItemModel.formatarDinheiro(p.preco!)}"}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                  secondary: IconButton(
                    tooltip: 'Corrigir',
                    onPressed: _importando ? null : () => _editar(p),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_totalSelecionado > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _algumSemPreco ? 'Total (itens com preço)' : 'Total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                      Text(
                        ItemModel.formatarDinheiro(_totalSelecionado),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: (_importando || _selecionados == 0)
                      ? null
                      : _importar,
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
            ],
          ),
        ),
      ),
    );
  }
}
