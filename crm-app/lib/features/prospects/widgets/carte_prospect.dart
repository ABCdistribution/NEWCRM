import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/vue_prospects.dart';

/// Pastille du groupe du pipeline (`classePast`) : gris, bleu, jaune ou vert ; gris « Perdu » sans groupe.
class PastilleGroupe extends StatelessWidget {
  const PastilleGroupe(this.prospect, {super.key});

  final Prospect prospect;

  @override
  Widget build(BuildContext context) {
    final variante = switch (prospect.groupe) {
      GroupeProspect.aContacter || null => VariantePastille.gris,
      GroupeProspect.rdvPris => VariantePastille.bleu,
      GroupeProspect.enNego => VariantePastille.jaune,
      GroupeProspect.reference => VariantePastille.vert,
    };
    return Pastille(libelleGroupeProspect(prospect), variante: variante);
  }
}

/// Carte d'un prospect de la liste (`carte` de `pageProspects`) : nom, classe, pastille du groupe, potentiel, prochaine
/// action prévue au planning et mention « En attente d'envoi ».
class CarteProspect extends StatelessWidget {
  const CarteProspect({
    super.key,
    required this.prospect,
    required this.etapes,
    required this.onTap,
    this.avecChef = false,
  });

  final Prospect prospect;

  /// Planning du profil, pour la prochaine action.
  final List<EtapePlanning> etapes;
  final VoidCallback onTap;

  /// Ajoute le chef de secteur responsable après la classe (« Classe A · Nadia H. »).
  final bool avecChef;

  @override
  Widget build(BuildContext context) {
    final p = prospect;
    final chef = p.cs;
    final prochaine = prochaineEtape(etapes, p.id);
    final suite = avecChef && chef != null && chef.isNotEmpty ? ' · $chef' : '';
    return AppCarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLigne(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nom, style: AppText.titreCarte),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Classe ${p.classe}$suite',
                        style: AppText.sousCarte,
                      ),
                    ),
                  ],
                ),
              ),
              PastilleGroupe(p),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Potentiel ',
                          style: AppText.t(13, c: AppColors.muted),
                        ),
                        TextSpan(
                          text: '${kf(p.pot)} k€/an',
                          style: AppText.t(13, w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (prochaine != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '📅 ${prochaine.rdv ? 'RDV' : 'Visite'} · ${joursCourts[prochaine.jour]} ${prochaine.heure}',
                    style: AppText.t(
                      12.5,
                      w: FontWeight.w700,
                      c: context.univers.violet,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (p.attente) const EnAttente(),
        ],
      ),
    );
  }
}
