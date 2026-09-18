import 'package:flutter/material.dart';
import '../constants.dart';

/// Cartão de estatística da home. Clicável: ativa/desativa um filtro.
class StatCard extends StatelessWidget {
  final String rotulo;
  final int valor;
  final Color cor;
  final bool ativo;
  final VoidCallback onTap;

  const StatCard({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.cor,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: '$rotulo: $valor itens',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ativo
                    ? const Color(AppConstants.corAzul)
                    : Colors.black.withValues(alpha: 0.06),
                width: ativo ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$valor',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: cor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
