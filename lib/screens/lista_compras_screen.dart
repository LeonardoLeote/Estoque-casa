import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../main.dart';
import '../models/item_model.dart';
import '../widgets/empty_state.dart';

/// Tudo que está baixo ou faltando, agrupado por categoria.
/// Marcar um item é só visual — não mexe no estoque.
class ListaComprasScreen extends StatefulWidget {
  final List<ItemModel> itens;
  const ListaComprasScreen({super.key, required this.itens});

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  final _marcados = <String>{};

  late final List<ItemModel> _comprar = widget.itens
      .where((i) => i.precisaComprar)
      .toList()
    ..sort((a, b) {
      // Faltando vem antes de baixo; depois ordem alfabética.
      final porStatus = a.status.index.compareTo(b.status.index);
      return porStatus != 0 ? -porStatus : a.nome.compareTo(b.nome);
    });

  Map<String, List<ItemModel>> get _porCategoria {
    final mapa = <String, List<ItemModel>>{};
    for (final i in _comprar) {
      mapa.putIfAbsent(i.categoria, () => []).add(i);
    }
    return mapa;
  }

  String _montarTexto() {
    final buffer = StringBuffer('🛒 *Lista de compras*\n');
    _porCategoria.forEach((categoria, itens) {
      buffer.writeln('\n*$categoria*');
      for (final i in itens) {
        final marca = _marcados.contains(i.id) ? '✅' : '▫️';
        final falta = i.status == ItemStatus.vazio
            ? 'acabou'
            : 'restam ${i.quantidadeFormatada}';
        buffer.writeln('$marca ${i.nome} — $falta');
      }
    });
    buffer.writeln('\n_Enviado pelo Estoque Casa_');
    return buffer.toString();
  }

  Future<void> _compartilhar() async {
    if (_comprar.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(text: _montarTexto(), subject: 'Lista de compras'),
      );
    } catch (_) {
      if (mounted) context.avisoErro('Não consegui abrir o compartilhamento.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _porCategoria;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corVerde),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '🛒 Lista de compras',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        actions: [
          if (_marcados.isNotEmpty)
            IconButton(
              tooltip: 'Limpar seleção',
              onPressed: () => setState(_marcados.clear),
              icon: const Icon(Icons.remove_done),
            ),
        ],
      ),
      body: _comprar.isEmpty
          ? const EmptyState(
              emoji: '🎉',
              titulo: 'Nada para comprar!',
              descricao: 'Todo o estoque está acima do mínimo. Bom trabalho.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Text(
                  '${_comprar.length} ${_comprar.length == 1 ? "item" : "itens"} '
                  'para repor · ${_marcados.length} marcado(s)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                for (final entrada in grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      entrada.key,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final item in entrada.value)
                          _LinhaCompra(
                            item: item,
                            marcado: _marcados.contains(item.id),
                            onToggle: () => setState(() {
                              if (!_marcados.remove(item.id)) {
                                _marcados.add(item.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _comprar.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _compartilhar,
                    icon: const Icon(Icons.share),
                    label: const Text(
                      'Compartilhar lista',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(AppConstants.corVerde),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LinhaCompra extends StatelessWidget {
  final ItemModel item;
  final bool marcado;
  final VoidCallback onToggle;

  const _LinhaCompra({
    required this.item,
    required this.marcado,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: marcado,
              onChanged: (_) => onToggle(),
              activeColor: const Color(AppConstants.corVerde),
            ),
            Text(item.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        decoration:
                            marcado ? TextDecoration.lineThrough : null,
                        color: marcado
                            ? Colors.black.withValues(alpha: 0.35)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.status == ItemStatus.vazio
                          ? 'Acabou'
                          : 'Restam ${item.quantidadeFormatada} '
                              '(mín. ${ItemModel.formatarNumero(item.minimo)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.statusCor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
