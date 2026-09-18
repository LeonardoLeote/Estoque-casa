import 'package:flutter/material.dart';

/// Estado vazio reutilizável (lista sem itens, busca sem resultado, erro).
class EmptyState extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String descricao;
  final String? textoBotao;
  final VoidCallback? onBotao;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.titulo,
    required this.descricao,
    this.textoBotao,
    this.onBotao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            if (textoBotao != null && onBotao != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onBotao, child: Text(textoBotao!)),
            ],
          ],
        ),
      ),
    );
  }
}
