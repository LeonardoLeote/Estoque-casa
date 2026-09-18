import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../constants.dart';
import '../models/item_model.dart';

/// Linha da lista de estoque: emoji, nome, categoria, quantidade e ajuste
/// rápido. Arraste para a esquerda para excluir.
class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onExcluir;

  /// Bloqueia os botões enquanto um ajuste deste item está em voo.
  final bool ocupado;

  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onExcluir,
    this.ocupado = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = item.statusCor;
    final destacado = item.status != ItemStatus.ok;

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onExcluir(),
            backgroundColor: const Color(AppConstants.corVermelho),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Excluir',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Barra lateral colorida: só aparece quando há alerta.
                  Container(width: 5, color: destacado ? cor : Colors.transparent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              item.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      item.categoria,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _Badge(texto: item.statusTexto, cor: cor),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _BotaoAjuste(
                            icone: Icons.remove,
                            // Nunca deixa a quantidade ficar negativa.
                            onTap: (ocupado || item.quantidade <= 0)
                                ? null
                                : onDecrementar,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 58),
                            child: Text(
                              item.quantidadeFormatada,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _BotaoAjuste(
                            icone: Icons.add,
                            onTap: ocupado ? null : onIncrementar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Badge({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: cor,
        ),
      ),
    );
  }
}

class _BotaoAjuste extends StatelessWidget {
  final IconData icone;
  final VoidCallback? onTap;
  const _BotaoAjuste({required this.icone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: habilitado ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icone,
          size: 18,
          color: Colors.black.withValues(alpha: habilitado ? 0.75 : 0.22),
        ),
      ),
    );
  }
}
