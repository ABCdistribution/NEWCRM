import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/code_barres.dart';

/// Géométrie en modules (1 module = 1 unité) : barres de 44 de haut, gardes des EAN plus longues de 8, caractères
/// sous les barres. Même dessin que la fiche produit du web.
const _hautMarge = 2.0;
const _hautBarres = 44.0;
const _hautGardes = 52.0;
const _ligneDeBase = 53.0;
const _hauteurTotale = 56.0;
const _tailleChiffre = 8.0;

class _Dessin {
  const _Dessin(
    this.silenceGauche,
    this.silenceDroite,
    this.modules,
    this.gardes,
    this.textes,
  );

  final double silenceGauche;
  final double silenceDroite;
  final int modules;
  final List<Barre> gardes;
  final List<({String c, double x})> textes;

  double get largeurTotale => silenceGauche + modules + silenceDroite;

  factory _Dessin.de(SymboleCodeBarres s) {
    switch (s.type) {
      case TypeCodeBarres.ean13:
        const sg = 11.0;
        return _Dessin(
          sg,
          7,
          95,
          const [(x: 0, largeur: 3), (x: 45, largeur: 5), (x: 92, largeur: 3)],
          [
            for (var i = 0; i < s.texte.length; i++)
              (
                c: s.texte[i],
                // Chiffre 0 : dans la zone de silence ; 1 à 6 : sous le groupe de gauche ; 7 à 12 : sous celui de droite.
                x: i == 0
                    ? sg / 2
                    : i <= 6
                    ? sg + 3 + (i - 1) * 7 + 3.5
                    : sg + 50 + (i - 7) * 7 + 3.5,
              ),
          ],
        );
      case TypeCodeBarres.ean8:
        const sg = 7.0;
        return _Dessin(
          sg,
          sg,
          67,
          const [(x: 0, largeur: 3), (x: 31, largeur: 5), (x: 64, largeur: 3)],
          [
            for (var i = 0; i < s.texte.length; i++)
              (
                c: s.texte[i],
                x: sg + (i < 4 ? 3 + i * 7 : 36 + (i - 4) * 7) + 3.5,
              ),
          ],
        );
      case TypeCodeBarres.code128:
        const sg = 10.0;
        final n = s.modules.length;
        return _Dessin(sg, sg, n, const [], [(c: s.texte, x: sg + n / 2)]);
    }
  }
}

/// Code-barres dessiné pour un gencode : barres noires sur fond blanc, zones de silence, caractères dessous.
///
/// EAN-13 (et UPC-A), EAN-8 si le numéro est valide ; sinon Code 128 qui encode exactement le numéro. Ne dessine rien
/// si la valeur est vide ou non encodable.
class CodeBarres extends StatelessWidget {
  const CodeBarres(this.gencode, {super.key, this.largeurMax = 256});

  final String? gencode;
  final double largeurMax;

  @override
  Widget build(BuildContext context) {
    final symbole = symboleCodeBarres(gencode);
    if (symbole == null) return const SizedBox.shrink();
    final dessin = _Dessin.de(symbole);
    return Semantics(
      image: true,
      label: 'Code-barres ${symbole.type.libelle} ${symbole.texte}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) {
            final largeur = math.min(
              c.maxWidth.isFinite ? c.maxWidth : largeurMax,
              largeurMax,
            );
            return SizedBox(
              width: largeur,
              height: largeur * _hauteurTotale / dessin.largeurTotale,
              child: CustomPaint(painter: _Peintre(symbole, dessin)),
            );
          },
        ),
      ),
    );
  }
}

class _Peintre extends CustomPainter {
  _Peintre(this.symbole, this.dessin);

  final SymboleCodeBarres symbole;
  final _Dessin dessin;

  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / dessin.largeurTotale; // pixels par module
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final noir = Paint()..color = Colors.black;
    for (final b in barresDeModules(symbole.modules)) {
      final garde = dessin.gardes.any(
        (g) => b.x >= g.x && b.x + b.largeur <= g.x + g.largeur,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          (dessin.silenceGauche + b.x) * e,
          _hautMarge * e,
          b.largeur * e,
          (garde ? _hautGardes : _hautBarres) * e,
        ),
        noir,
      );
    }
    for (final t in dessin.textes) {
      final tp = TextPainter(
        text: TextSpan(
          text: t.c,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: _tailleChiffre * e,
            color: Colors.black,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      tp.paint(canvas, Offset(t.x * e - tp.width / 2, _ligneDeBase * e - base));
    }
  }

  @override
  bool shouldRepaint(_Peintre ancien) =>
      ancien.symbole.modules != symbole.modules ||
      ancien.symbole.texte != symbole.texte;
}
