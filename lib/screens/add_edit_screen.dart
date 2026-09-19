import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../main.dart';
import '../models/item_model.dart';
import '../services/categoria_service.dart';
import '../services/supabase_service.dart';

/// Adiciona um item novo ou edita um existente.
/// Retorna `true` via `Navigator.pop` quando algo mudou.
class AddEditScreen extends StatefulWidget {
  final ItemModel? item;
  const AddEditScreen({super.key, this.item});

  bool get editando => item != null;

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _quantidade;
  late final TextEditingController _minimo;
  late final TextEditingController _preco;

  late String _categoria;
  late String _unidade;
  late String _emoji;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nome = TextEditingController(text: item?.nome ?? '');
    _quantidade = TextEditingController(
      text: item == null ? '' : ItemModel.formatarNumero(item.quantidade),
    );
    _minimo = TextEditingController(
      text: item == null ? '' : ItemModel.formatarNumero(item.minimo),
    );
    _preco = TextEditingController(
      text: item?.preco == null
          ? ''
          : item!.preco!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _categoria = item?.categoria ?? CategoriaService.nomes.first;
    _unidade = item?.unidade ?? 'un';
    _emoji = item?.emoji ?? CategoriaService.emojisDe(_categoria).first;
  }

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    _minimo.dispose();
    _preco.dispose();
    super.dispose();
  }

  double _lerNumero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  /// Campo vazio significa "sem preço informado", não "custa zero".
  double? _lerPrecoOpcional() {
    final texto = _preco.text.trim();
    if (texto.isEmpty) return null;
    final v = double.tryParse(texto.replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final agora = DateTime.now();
    final base = widget.item;
    final item = ItemModel(
      id: base?.id ?? '',
      nome: _nome.text.trim(),
      categoria: _categoria,
      quantidade: _lerNumero(_quantidade),
      unidade: _unidade,
      minimo: _lerNumero(_minimo),
      emoji: _emoji,
      preco: _lerPrecoOpcional(),
      createdAt: base?.createdAt ?? agora,
      updatedAt: agora,
    );

    try {
      if (base == null) {
        await SupabaseService.addItem(item);
      } else {
        await SupabaseService.updateItem(
          item,
          quantidadeAnterior: base.quantidade,
        );
      }
      if (!mounted) return;
      context.avisoSucesso(
        base == null ? 'Item adicionado!' : 'Item atualizado!',
      );
      Navigator.pop(context, true);
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      context.avisoErro(e.mensagem);
    }
  }

  Future<void> _excluir() async {
    final item = widget.item;
    if (item == null) return;

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

    setState(() => _salvando = true);
    try {
      await SupabaseService.deleteItem(item);
      if (!mounted) return;
      context.avisoSucesso('"${item.nome}" excluído.');
      Navigator.pop(context, true);
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      context.avisoErro(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emojis = CategoriaService.emojisDe(_categoria);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corVerde),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.editando ? 'Editar item' : 'Novo item',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        actions: [
          if (widget.editando)
            IconButton(
              tooltip: 'Excluir',
              onPressed: _salvando ? null : _excluir,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _Rotulo('Nome do produto'),
            TextFormField(
              controller: _nome,
              enabled: !_salvando,
              textCapitalization: TextCapitalization.sentences,
              decoration: _campo('Ex: Arroz Tipo 1'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Dê um nome ao produto'
                  : null,
            ),
            const SizedBox(height: 20),

            _Rotulo('Categoria'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in CategoriaService.nomes)
                  ChoiceChip(
                    label: Text(cat),
                    selected: _categoria == cat,
                    showCheckmark: false,
                    selectedColor: const Color(AppConstants.corVerde),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _categoria == cat ? Colors.white : Colors.black87,
                    ),
                    onSelected: _salvando
                        ? null
                        : (_) => setState(() {
                              _categoria = cat;
                              // O emoji atual pode não existir na nova
                              // categoria: cai para o primeiro dela.
                              final novos =
                                  CategoriaService.emojisDe(cat);
                              if (!novos.contains(_emoji)) _emoji = novos.first;
                            }),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            _Rotulo('Ícone'),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in emojis)
                    InkWell(
                      onTap: _salvando ? null : () => setState(() => _emoji = e),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _emoji == e
                              ? const Color(AppConstants.corVerde)
                                  .withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emoji == e
                                ? const Color(AppConstants.corVerde)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Rotulo('Quantidade'),
                      TextFormField(
                        controller: _quantidade,
                        enabled: !_salvando,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: _campo('0'),
                        validator: _validarNumero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Rotulo('Alerta abaixo de'),
                      TextFormField(
                        controller: _minimo,
                        enabled: !_salvando,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: _campo('0'),
                        validator: _validarNumero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 20),

            _Rotulo('Preço unitário (opcional)'),
            TextFormField(
              controller: _preco,
              enabled: !_salvando,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _campo('Ex: 24,90').copyWith(
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              validator: (v) {
                final texto = (v ?? '').trim();
                if (texto.isEmpty) return null;
                final n = double.tryParse(texto.replaceAll(',', '.'));
                if (n == null) return 'Número inválido';
                if (n < 0) return 'Não pode ser negativo';
                return null;
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Usado para estimar o custo da lista de compras. Deixe vazio se não souber.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Deixe o alerta em 0 para não receber aviso de estoque baixo deste item.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),

            _Rotulo('Unidade'),
            Wrap(
              spacing: 8,
              children: [
                for (final u in AppConstants.unidades)
                  ChoiceChip(
                    label: Text(u),
                    selected: _unidade == u,
                    showCheckmark: false,
                    selectedColor: const Color(AppConstants.corAzul),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _unidade == u ? Colors.white : Colors.black87,
                    ),
                    onSelected:
                        _salvando ? null : (_) => setState(() => _unidade = u),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(AppConstants.corVerde),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _salvando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Salvar',
                      style: TextStyle(
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

  String? _validarNumero(String? v) {
    final texto = (v ?? '').trim();
    if (texto.isEmpty) return null; // vazio = 0
    final n = double.tryParse(texto.replaceAll(',', '.'));
    if (n == null) return 'Número inválido';
    if (n < 0) return 'Não pode ser negativo';
    return null;
  }

  InputDecoration _campo(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
}

class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
      );
}
