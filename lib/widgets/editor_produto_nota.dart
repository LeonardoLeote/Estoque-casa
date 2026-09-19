import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/item_model.dart';
import '../services/gemini_service.dart';

/// Folha para corrigir um produto lido da nota antes de importar.
///
/// Devolve `true` quando o usuário salvou (o [produto] é alterado no lugar).
class EditorProdutoNota extends StatefulWidget {
  final ProdutoNota produto;
  const EditorProdutoNota({super.key, required this.produto});

  static Future<bool> abrir(BuildContext context, ProdutoNota produto) async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditorProdutoNota(produto: produto),
    );
    return salvou ?? false;
  }

  @override
  State<EditorProdutoNota> createState() => _EditorProdutoNotaState();
}

class _EditorProdutoNotaState extends State<EditorProdutoNota> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _quantidade;
  late final TextEditingController _preco;
  late String _categoria;
  late String _unidade;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    _nome = TextEditingController(text: p.nome);
    _quantidade =
        TextEditingController(text: ItemModel.formatarNumero(p.quantidade));
    _preco = TextEditingController(
      text: p.preco == null
          ? ''
          : p.preco!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _categoria = p.categoria;
    _unidade = p.unidade;
    _emoji = p.emoji;
  }

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    _preco.dispose();
    super.dispose();
  }

  double? _lerNumero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    final p = widget.produto;
    p.nome = _nome.text.trim();
    p.categoria = _categoria;
    p.unidade = _unidade;
    p.emoji = _emoji;
    p.quantidade = _lerNumero(_quantidade) ?? 1;
    final preco = _lerNumero(_preco);
    p.preco = (preco == null || preco <= 0) ? null : preco;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final emojis = AppConstants.emojisDaCategoria(_categoria);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Corrigir produto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: _campo('Nome', 'Ex: Arroz Tipo 1'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantidade,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: _campo('Quantidade', '1'),
                    validator: _validarPositivo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preco,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: _campo('Preço unitário', 'opcional'),
                    validator: _validarPrecoOpcional,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _Rotulo('Categoria'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in AppConstants.categorias)
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
                    onSelected: (_) => setState(() {
                      _categoria = cat;
                      final novos = AppConstants.emojisDaCategoria(cat);
                      if (!novos.contains(_emoji)) _emoji = novos.first;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),

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
                    onSelected: (_) => setState(() => _unidade = u),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            _Rotulo('Ícone'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in emojis)
                  InkWell(
                    onTap: () => setState(() => _emoji = e),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
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
                              : Colors.black.withValues(alpha: 0.08),
                          width: _emoji == e ? 2 : 1,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppConstants.corVerde),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Salvar correção',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validarPositivo(String? v) {
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null) return 'Número inválido';
    if (n <= 0) return 'Deve ser maior que zero';
    return null;
  }

  String? _validarPrecoOpcional(String? v) {
    final texto = (v ?? '').trim();
    if (texto.isEmpty) return null;
    final n = double.tryParse(texto.replaceAll(',', '.'));
    if (n == null) return 'Número inválido';
    if (n < 0) return 'Não pode ser negativo';
    return null;
  }

  InputDecoration _campo(String rotulo, String hint) => InputDecoration(
        labelText: rotulo,
        hintText: hint,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.03),
        isDense: true,
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
