import 'package:flutter/material.dart';

import '../constants.dart';
import '../main.dart';
import '../models/categoria_model.dart';
import '../services/categoria_service.dart';
import '../services/supabase_service.dart';
import '../widgets/seletor_emoji.dart';

/// Cria uma categoria nova ou edita uma existente (nome, ícone e o conjunto
/// de ícones oferecido aos itens dela).
class EditarCategoriaScreen extends StatefulWidget {
  final CategoriaModel? categoria;
  const EditarCategoriaScreen({super.key, this.categoria});

  bool get editando => categoria != null;

  @override
  State<EditarCategoriaScreen> createState() => _EditarCategoriaScreenState();
}

class _EditarCategoriaScreenState extends State<EditarCategoriaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late String _emoji;
  late List<String> _emojis;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.categoria;
    _nome = TextEditingController(text: c?.nome ?? '');
    _emoji = c?.emoji ?? '📦';
    _emojis = List<String>.from(c?.emojis ?? const ['📦']);
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _adicionarIcone() async {
    final e = await SeletorEmoji.abrir(context);
    if (e == null || !mounted) return;
    if (_emojis.contains(e)) {
      context.avisoInfo('Esse ícone já está na lista.');
      return;
    }
    setState(() => _emojis.add(e));
  }

  Future<void> _trocarIconeDaCategoria() async {
    final e = await SeletorEmoji.abrir(context, atual: _emoji);
    if (e == null || !mounted) return;
    setState(() {
      _emoji = e;
      // O ícone da categoria também serve para os itens dela.
      if (!_emojis.contains(e)) _emojis.insert(0, e);
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_emojis.isEmpty) {
      context.avisoErro('Adicione pelo menos um ícone.');
      return;
    }

    setState(() => _salvando = true);
    final nome = _nome.text.trim();
    final original = widget.categoria;

    try {
      if (original != null && original.nome != nome) {
        // Renomear move os itens junto, senão eles ficariam órfãos.
        await CategoriaService.renomear(original.nome, nome);
        await CategoriaService.salvar(
          CategoriaModel(
            nome: nome,
            emoji: _emoji,
            emojis: _emojis,
            ordem: original.ordem,
          ),
        );
      } else {
        await CategoriaService.salvar(
          CategoriaModel(
            nome: nome,
            emoji: _emoji,
            emojis: _emojis,
            ordem: original?.ordem ?? 100,
          ),
        );
      }
      if (!mounted) return;
      context.avisoSucesso(
        widget.editando ? 'Categoria atualizada!' : 'Categoria criada!',
      );
      Navigator.pop(context, true);
    } on EstoqueException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      context.avisoErro(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corVerde),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.editando ? 'Editar categoria' : 'Nova categoria',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
          children: [
            Center(
              child: InkWell(
                onTap: _salvando ? null : _trocarIconeDaCategoria,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.corVerde)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(_emoji, style: const TextStyle(fontSize: 44)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _salvando ? null : _trocarIconeDaCategoria,
                child: const Text('Trocar ícone da categoria'),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _nome,
              enabled: !_salvando,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Besteiras',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) {
                final nome = (v ?? '').trim();
                if (nome.isEmpty) return 'Dê um nome à categoria';
                final mudouNome = widget.categoria?.nome != nome;
                if (mudouNome && CategoriaService.existe(nome)) {
                  return 'Já existe uma categoria com esse nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ÍCONES DOS ITENS (${_emojis.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                TextButton.icon(
                  onPressed: _salvando ? null : _adicionarIcone,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            Text(
              'Toque num ícone para remover.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
              ),
              child: _emojis.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhum ícone ainda. Toque em "Adicionar".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in _emojis)
                          InkWell(
                            onTap: _salvando
                                ? null
                                : () => setState(() => _emojis.remove(e)),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                      ],
                    ),
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
}
