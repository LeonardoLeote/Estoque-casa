import 'package:flutter/material.dart';
import '../constants.dart';

/// Barra horizontal de categorias.
class CategoryFilter extends StatelessWidget {
  final String selecionada;
  final ValueChanged<String> onSelecionar;

  const CategoryFilter({
    super.key,
    required this.selecionada,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppConstants.categoriasFiltro.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = AppConstants.categoriasFiltro[i];
          final ativo = cat == selecionada;
          return ChoiceChip(
            label: Text(cat),
            selected: ativo,
            onSelected: (_) => onSelecionar(cat),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: ativo ? Colors.white : Colors.black87,
            ),
            selectedColor: const Color(AppConstants.corVerde),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: ativo
                  ? const Color(AppConstants.corVerde)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          );
        },
      ),
    );
  }
}
