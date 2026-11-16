import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/prospects_state.dart';

/// Nombre qui part de sa dernière valeur affichée et rejoint la nouvelle en 450 ms, courbe `easeOutCubic`
/// (maquette : `data-cnt`, `animerCompteurs` l.594-606).
///
/// `cle` identifie le compteur : sa dernière valeur est mémorisée dans `compteursPrecProvider`, de sorte qu'un compteur
/// qui réapparaît (retour sur l'onglet) repart de ce qu'il affichait la dernière fois. La première fois, il n'anime rien.
class CompteurAnime extends ConsumerStatefulWidget {
  const CompteurAnime({
    super.key,
    required this.cle,
    required this.valeur,
    required this.style,
  });

  final String cle;
  final int valeur;
  final TextStyle style;

  @override
  ConsumerState<CompteurAnime> createState() => _CompteurAnimeState();
}

class _CompteurAnimeState extends ConsumerState<CompteurAnime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late int _debut;
  late int _fin;

  @override
  void initState() {
    super.initState();
    _viser(widget.valeur);
  }

  @override
  void didUpdateWidget(CompteurAnime ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.valeur != widget.valeur) _viser(widget.valeur);
  }

  /// Mémorise la valeur visée et lance le comptage depuis la dernière valeur affichée.
  void _viser(int fin) {
    final precedentes = ref.read(compteursPrecProvider);
    _debut = precedentes[widget.cle] ?? fin;
    _fin = fin;
    precedentes[widget.cle] = fin;
    if (_debut != fin) _controleur.forward(from: 0);
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controleur,
      builder: (context, _) {
        final e = Curves.easeOutCubic.transform(_controleur.value);
        final v = (_debut + (_fin - _debut) * e).round();
        return Text('$v', style: widget.style);
      },
    );
  }
}
