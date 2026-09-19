import 'package:flutter/material.dart';

import '../constants.dart';

/// Catálogo de ícones para montar categorias, agrupado por tema.
class CatalogoEmojis {
  static const grupos = <String, List<String>>{
    'Frutas': ['🍎','🍏','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍈','🍒',
               '🍑','🥭','🍍','🥥','🥝','🍅','🫒','🥑'],
    'Verduras': ['🥬','🥦','🥒','🌶️','🫑','🌽','🥕','🧄','🧅','🥔','🍠',
                 '🍄','🥗','🫘','🥜','🌰'],
    'Carnes e ovos': ['🥩','🍖','🍗','🥓','🌭','🍔','🐟','🍤','🦐','🦑',
                      '🦀','🦞','🥚','🍳','🧆'],
    'Padaria': ['🍞','🥖','🥐','🥯','🫓','🥨','🧇','🥞','🍰','🎂','🧁',
                '🥧','🍪','🍩'],
    'Besteiras': ['🍕','🍔','🌭','🥪','🌮','🌯','🍟','🍿','🍫','🍬','🍭',
                  '🍦','🍨','🍧','🥟','🍣','🍱','🍜','🍝'],
    'Laticínios': ['🥛','🧀','🧈','🍦','🥣','🍶'],
    'Bebidas': ['💧','🧃','☕','🍵','🥤','🧋','🍺','🍻','🍷','🍾','🥂',
                '🥃','🍹','🧉','🫗'],
    'Temperos': ['🧂','🍯','🫙','🥫','🍶','🌿','🍃'],
    'Limpeza': ['🧴','🧹','🧽','🪣','🧼','🫧','🧺','🧻','🗑️','🪒','🧯'],
    'Higiene': ['🪥','🧼','🧻','💊','🩹','🧷','💈'],
    'Casa': ['🏠','📦','🔋','💡','🕯️','🔌','🪫','🧰','🔦','🪴','🧊'],
    'Outros': ['📦','⭐','❤️','🔥','✨','🎁','🛒','🍴','🥄','🍽️'],
  };

  static List<String> get todos =>
      [for (final lista in grupos.values) ...lista];
}

/// Escolhe um emoji do catálogo, ou aceita um colado do teclado.
class SeletorEmoji extends StatefulWidget {
  final String? selecionado;
  const SeletorEmoji({super.key, this.selecionado});

  static Future<String?> abrir(BuildContext context, {String? atual}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SeletorEmoji(selecionado: atual),
      );

  @override
  State<SeletorEmoji> createState() => _SeletorEmojiState();
}

class _SeletorEmojiState extends State<SeletorEmoji> {
  final _personalizado = TextEditingController();

  @override
  void dispose() {
    _personalizado.dispose();
    super.dispose();
  }

  void _usarPersonalizado() {
    final texto = _personalizado.text.trim();
    if (texto.isEmpty) return;
    // Pega só o primeiro "caractere visível": emojis compostos (bandeiras,
    // tons de pele) ocupam vários code units.
    final chars = texto.characters;
    Navigator.pop(context, chars.first);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Escolher ícone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _personalizado,
                    decoration: InputDecoration(
                      hintText: 'Ou cole um emoji do teclado',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _usarPersonalizado(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _usarPersonalizado,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(AppConstants.corVerde),
                  ),
                  child: const Text('Usar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final grupo in CatalogoEmojis.grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Text(
                      grupo.key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in grupo.value)
                        _Celula(
                          emoji: e,
                          ativo: e == widget.selecionado,
                          onTap: () => Navigator.pop(context, e),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Celula extends StatelessWidget {
  final String emoji;
  final bool ativo;
  final VoidCallback onTap;
  const _Celula({
    required this.emoji,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo
              ? const Color(AppConstants.corVerde).withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativo
                ? const Color(AppConstants.corVerde)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
