import 'package:flutter/material.dart';

import '../constants.dart';
import '../main.dart';
import '../models/categoria_model.dart';
import '../services/categoria_service.dart';
import '../services/supabase_service.dart';
import '../widgets/empty_state.dart';
import 'editar_categoria_screen.dart';

/// Lista as categorias da casa e leva para criar/editar.
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  List<CategoriaModel> _categorias = CategoriaService.categorias;
  bool _carregando = true;

  /// Vira true quando algo mudou, para a home recarregar ao voltar.
  bool _mudou = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await CategoriaService.carregar();
    if (mounted) {
      setState(() {
        _categorias = lista;
        _carregando = false;
      });
    }
  }

  Future<void> _abrirEditor([CategoriaModel? categoria]) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarCategoriaScreen(categoria: categoria),
      ),
    );
    if (salvou == true) {
      _mudou = true;
      await _carregar();
    }
  }

  Future<void> _excluir(CategoriaModel categoria) async {
    final emUso = await CategoriaService.contarItens(categoria.nome);
    if (!mounted) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${categoria.nome}"?'),
        content: Text(
          emUso == 0
              ? 'Nenhum item usa esta categoria.'
              : '$emUso ${emUso == 1 ? "item usa" : "itens usam"} esta '
                  'categoria. Eles continuam no estoque, mas ficam sem '
                  'categoria válida até você editá-los.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppConstants.corVermelho),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    try {
      await CategoriaService.excluir(categoria.nome);
      _mudou = true;
      if (!mounted) return;
      context.avisoSucesso('Categoria excluída.');
      await _carregar();
    } on EstoqueException catch (e) {
      if (mounted) context.avisoErro(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _mudou);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(AppConstants.corVerde),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '🏷️ Categorias',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
          ),
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _categorias.isEmpty
                ? const EmptyState(
                    emoji: '🏷️',
                    titulo: 'Nenhuma categoria',
                    descricao: 'Crie a primeira no botão abaixo.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      Text(
                        'As categorias são compartilhadas por todos os '
                        'celulares da casa.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final c in _categorias)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.white,
                            child: ListTile(
                              onTap: () => _abrirEditor(c),
                              leading: Text(
                                c.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                              title: Text(
                                c.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${c.emojis.length} '
                                '${c.emojis.length == 1 ? "ícone" : "ícones"}'
                                ' · ${c.emojis.take(8).join(" ")}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Excluir',
                                onPressed: () => _excluir(c),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirEditor(),
          backgroundColor: const Color(AppConstants.corVerde),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text(
            'Nova categoria',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
