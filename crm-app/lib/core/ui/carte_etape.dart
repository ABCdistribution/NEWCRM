import 'package:flutter/material.dart';

import '../logic/classes.dart';
import '../theme/theme.dart';
import 'cartes.dart';

/// Ligne d'horaire du planning (`.heure-l` + `.etape-c`) : heure à gauche, carte colorée à droite.
///
/// Partagée par le lot planning et le lot équipe (planning d'un promoteur ou d'un chef de secteur).
/// Les couleurs viennent de `styleEtapePlanning` (logique).
class CarteEtapePlanning extends StatelessWidget {
  const CarteEtapePlanning({
    super.key,
    required this.heure,
    required this.titre,
    required this.libelle,
    required this.fond,
    required this.texte,
    this.detail,
    this.onTap,
    this.onModifier,
    this.classe,
  });

  /// Classe du client ou du prospect visé ; aucune pastille si elle est inconnue.
  final String? classe;

  /// « 09:30 », ou « — » sans heure.
  final String heure;
  final String titre;

  /// Libellé de la pastille (« Client », « Prospect », « Fait ✓ », « ADM »…).
  final String libelle;
  final Color fond;
  final Color texte;

  /// Détail sous le titre (« Visite simple · RDV · Relance baisse de CA »).
  final String? detail;
  final VoidCallback? onTap;

  /// Crayon « ✎ » de modification, affiché si renseigné.
  final VoidCallback? onModifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(heure, style: AppText.t(15, w: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: fond,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            titre,
                            style: AppText.t(
                              14.5,
                              w: FontWeight.w700,
                              c: texte,
                            ),
                          ),
                        ),
                        if (classeValide(classe).isNotEmpty) ...[
                          const SizedBox(width: 8),
                          PastilleClasse(classe),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            libelle,
                            softWrap: false,
                            style: AppText.t(
                              11.5,
                              w: FontWeight.w800,
                              c: texte,
                            ),
                          ),
                        ),
                        if (onModifier != null)
                          GestureDetector(
                            onTap: onModifier,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text('✎', style: AppText.t(15, c: texte)),
                            ),
                          ),
                      ],
                    ),
                    if (detail != null && detail!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          detail!,
                          style: AppText.t(
                            12.5,
                            c: texte.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
