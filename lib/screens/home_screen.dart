import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../main.dart';
import '../models/item_model.dart';
import '../services/gemini_service.dart';
import '../services/local_cache.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import '../widgets/category_filter.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/stat_card.dart';
import 'add_edit_screen.dart';
import 'historico_screen.dart';
import 'lista_compras_screen.dart';
import 'revisao_nota_screen.dart';

enum FiltroStatus { todos, baixo, vazio }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _buscaController = TextEditingController();

  List<ItemModel> _itens = [];
  bool _carregando = true;
  bool _offline = false;
  bool _escaneando = false;
  String _busca = '';
  String _categoria = 'Todos';
  FiltroStatus _filtroStatus = FiltroStatus.todos;

  /// IDs com um ajuste de quantidade em voo — evita duplo toque no + / -.
  final _emAndamento = <String>{};

  RealtimeChannel? _canal;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    final canal = _canal;
    if (canal != null) SupabaseService.removerCanal(canal);
    super.dispose();
  }

  Future<void> _iniciar() async {
    // 1) Cache primeiro: a tela aparece preenchida mesmo sem rede.
    final cache = await LocalCache.lerItens();
    if (mounted && cache.isNotEmpty) {
      setState(() {
        _itens = cache;
        _carregando = false;
      });
    }

    await _carregar(silencioso: true);

    // 2) Realtime: o Supabase reconecta sozinho quando a rede volta.
    _canal = SupabaseService.subscribeItems(
      (itens) {
        if (!mounted) return;
        setState(() {
          _itens = itens;
          _offline = false;
        });
        NotificationService.checkAndNotify(itens);
      },
      onErro: (_) {
        if (mounted) setState(() => _offline = true);
      },
    );
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (mounted && !silencioso) setState(() => _carregando = true);
    try {
      final itens = await SupabaseService.getItems();
      if (!mounted) return;
      setState(() {
        _itens = itens;
        _carregando = false;
        _offline = false;
      });
      await NotificationService.checkAndNotify(itens);
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _offline = true;
      });
      if (!silencioso) context.avisoErro(e.mensagem);
    }
  }

  // ── Filtros ─────────────────────────────────────────────────────────

  List<ItemModel> get _filtrados {
    final busca = _busca.trim().toLowerCase();
    return _itens.where((i) {
      if (_categoria != 'Todos' && i.categoria != _categoria) return false;
      if (_filtroStatus == FiltroStatus.baixo &&
          i.status != ItemStatus.baixo) {
        return false;
      }
      if (_filtroStatus == FiltroStatus.vazio &&
          i.status != ItemStatus.vazio) {
        return false;
      }
      if (busca.isNotEmpty && !i.nome.toLowerCase().contains(busca)) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _totalBaixo =>
      _itens.where((i) => i.status == ItemStatus.baixo).length;
  int get _totalVazio =>
      _itens.where((i) => i.status == ItemStatus.vazio).length;

  void _alternarStatus(FiltroStatus alvo) {
    setState(() {
      _filtroStatus = _filtroStatus == alvo ? FiltroStatus.todos : alvo;
    });
  }

  // ── Ações ───────────────────────────────────────────────────────────

  /// Ajuste rápido pelo + / -. Aplica otimista na UI e desfaz se falhar.
  Future<void> _ajustar(ItemModel item, double delta) async {
    if (_emAndamento.contains(item.id)) return;

    final nova = (item.quantidade + delta).clamp(0.0, double.infinity);
    if (nova == item.quantidade) return;

    final atualizado = item.copyWith(quantidade: nova);
    setState(() {
      _emAndamento.add(item.id);
      _itens = [
        for (final i in _itens) i.id == item.id ? atualizado : i,
      ];
    });

    try {
      await SupabaseService.updateItem(
        atualizado,
        quantidadeAnterior: item.quantidade,
        acao: Acoes.ajustou,
      );
      await LocalCache.salvarItens(_itens);
      if (mounted) await NotificationService.checkAndNotify(_itens);
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() {
        _itens = [for (final i in _itens) i.id == item.id ? item : i];
      });
      context.avisoErro(e.mensagem);
    } finally {
      if (mounted) setState(() => _emAndamento.remove(item.id));
    }
  }

  Future<void> _excluir(ItemModel item) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text(
          '"${item.nome}" será removido do estoque. Essa ação não pode ser desfeita.',
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
      await SupabaseService.deleteItem(item);
      if (!mounted) return;
      setState(() => _itens = _itens.where((i) => i.id != item.id).toList());
      await LocalCache.salvarItens(_itens);
      if (mounted) context.avisoSucesso('"${item.nome}" excluído.');
    } on EstoqueException catch (e) {
      if (mounted) context.avisoErro(e.mensagem);
    }
  }

  Future<void> _abrirEdicao([ItemModel? item]) async {
    final mudou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditScreen(item: item)),
    );
    if (mudou == true) await _carregar();
  }

  // ── Nota fiscal ─────────────────────────────────────────────────────

  Future<void> _escanearNota() async {
    if (!AppConstants.geminiConfigurado) {
      context.avisoErro('Leitura de nota indisponível: GEMINI_API_KEY ausente.');
      return;
    }

    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                '🧾 Ler nota fiscal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;

    final XFile? foto;
    try {
      foto = await ImagePicker().pickImage(
        source: origem,
        imageQuality: 80,
        maxWidth: 1600,
      );
    } catch (_) {
      if (mounted) {
        context.avisoErro('Não consegui abrir a câmera. Confira a permissão.');
      }
      return;
    }
    if (foto == null || !mounted) return;

    setState(() => _escaneando = true);
    try {
      final produtos = await GeminiService.lerNotaFiscal(File(foto.path));
      if (!mounted) return;
      if (produtos.isEmpty) {
        context.avisoInfo('Nenhum produto reconhecido nessa nota.');
        return;
      }
      final importou = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RevisaoNotaScreen(produtos: produtos),
        ),
      );
      if (importou == true) await _carregar();
    } on GeminiException catch (e) {
      if (mounted) context.avisoErro(e.mensagem);
    } finally {
      if (mounted) setState(() => _escaneando = false);
    }
  }

  // ── Menu ────────────────────────────────────────────────────────────

  Future<void> _abrirMenu(String opcao) async {
    switch (opcao) {
      case 'historico':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoricoScreen()),
        );
      case 'compras':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListaComprasScreen(itens: _itens),
          ),
        );
      case 'sobre':
        final atualizado = await LocalCache.atualizadoEm();
        if (!mounted) return;
        showAboutDialog(
          context: context,
          applicationName: 'Estoque Casa',
          applicationVersion: '1.0.0',
          applicationIcon: const Text('🏠', style: TextStyle(fontSize: 36)),
          children: [
            const SizedBox(height: 8),
            Text('Usuário deste aparelho: ${UserService.nome}'),
            if (atualizado != null)
              Text(
                'Dados sincronizados em '
                '${atualizado.day.toString().padLeft(2, '0')}/'
                '${atualizado.month.toString().padLeft(2, '0')} '
                '${atualizado.hour.toString().padLeft(2, '0')}:'
                '${atualizado.minute.toString().padLeft(2, '0')}',
              ),
          ],
        );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corVerde),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '🏠 Estoque Casa',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _abrirMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'compras', child: Text('🛒 Lista de compras')),
              PopupMenuItem(value: 'historico', child: Text('🕓 Histórico')),
              PopupMenuItem(value: 'sobre', child: Text('ℹ️ Sobre')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_offline) const _BarraOffline(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                StatCard(
                  rotulo: 'Total',
                  valor: _itens.length,
                  cor: Colors.black87,
                  ativo: _filtroStatus == FiltroStatus.todos,
                  onTap: () =>
                      setState(() => _filtroStatus = FiltroStatus.todos),
                ),
                const SizedBox(width: 10),
                StatCard(
                  rotulo: '⚠️ Baixo',
                  valor: _totalBaixo,
                  cor: const Color(AppConstants.corAmarelo),
                  ativo: _filtroStatus == FiltroStatus.baixo,
                  onTap: () => _alternarStatus(FiltroStatus.baixo),
                ),
                const SizedBox(width: 10),
                StatCard(
                  rotulo: '🔴 Faltando',
                  valor: _totalVazio,
                  cor: const Color(AppConstants.corVermelho),
                  ativo: _filtroStatus == FiltroStatus.vazio,
                  onTap: () => _alternarStatus(FiltroStatus.vazio),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _buscaController,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _busca = v),
              decoration: InputDecoration(
                hintText: 'Buscar item...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _busca.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() => _busca = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CategoryFilter(
            selecionada: _categoria,
            onSelecionar: (c) => setState(() => _categoria = c),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _carregar,
              child: _corpo(lista),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_nota',
            onPressed: _escaneando ? null : _escanearNota,
            backgroundColor: const Color(AppConstants.corAzul),
            foregroundColor: Colors.white,
            tooltip: 'Ler nota fiscal',
            child: _escaneando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.document_scanner_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_add',
            onPressed: () => _abrirEdicao(),
            backgroundColor: const Color(AppConstants.corVerde),
            foregroundColor: Colors.white,
            tooltip: 'Adicionar item',
            child: const Icon(Icons.add, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _corpo(List<ItemModel> lista) {
    if (_carregando && _itens.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lista.isEmpty) {
      final filtrando = _busca.isNotEmpty ||
          _categoria != 'Todos' ||
          _filtroStatus != FiltroStatus.todos;

      // ListView para o pull-to-refresh continuar funcionando no vazio.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 380,
            child: filtrando
                ? EmptyState(
                    emoji: '🔍',
                    titulo: 'Nada por aqui',
                    descricao:
                        'Nenhum item bate com os filtros selecionados.',
                    textoBotao: 'Limpar filtros',
                    onBotao: () {
                      _buscaController.clear();
                      setState(() {
                        _busca = '';
                        _categoria = 'Todos';
                        _filtroStatus = FiltroStatus.todos;
                      });
                    },
                  )
                : EmptyState(
                    emoji: '📦',
                    titulo: 'Estoque vazio',
                    descricao:
                        'Adicione o primeiro item ou fotografe uma nota fiscal.',
                    textoBotao: 'Adicionar item',
                    onBotao: () => _abrirEdicao(),
                  ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final item = lista[i];
        return ItemCard(
          item: item,
          ocupado: _emAndamento.contains(item.id),
          onTap: () => _abrirEdicao(item),
          onIncrementar: () => _ajustar(item, 1),
          onDecrementar: () => _ajustar(item, -1),
          onExcluir: () => _excluir(item),
        );
      },
    );
  }
}

class _BarraOffline extends StatelessWidget {
  const _BarraOffline();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(AppConstants.corAmarelo),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 15, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Sem conexão — mostrando dados salvos no aparelho',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
