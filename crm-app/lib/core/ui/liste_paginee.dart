import 'package:flutter/material.dart';

import 'boutons.dart';

/// Liste qui ne construit que les premiers éléments, puis « Afficher plus » : indispensable avec un catalogue de
/// plusieurs milliers de produits (les construire tous d'un coup bloque l'application).
///
/// Revient aux premiers éléments quand le nombre total change (nouvelle recherche, nouveau filtre).
class ListePaginee<T> extends StatefulWidget {
  const ListePaginee({
    super.key,
    required this.elements,
    required this.constructeur,
    this.pas = 40,
  });

  final List<T> elements;
  final Widget Function(T element) constructeur;

  /// Nombre d'éléments affichés au départ et ajoutés à chaque « Afficher plus ».
  final int pas;

  @override
  State<ListePaginee<T>> createState() => _ListePagineeState<T>();
}

class _ListePagineeState<T> extends State<ListePaginee<T>> {
  late int _visibles = widget.pas;

  @override
  void didUpdateWidget(ListePaginee<T> ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.elements.length != widget.elements.length) {
      _visibles = widget.pas;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.elements.length;
    final n = _visibles < total ? _visibles : total;
    final reste = total - n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in widget.elements.take(n)) widget.constructeur(e),
        if (reste > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppBouton(
              'Afficher plus ($reste restants)',
              onPressed: () => setState(() => _visibles = n + widget.pas),
            ),
          ),
      ],
    );
  }
}
