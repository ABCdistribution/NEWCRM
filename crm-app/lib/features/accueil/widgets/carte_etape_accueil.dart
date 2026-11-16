import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../accueil_logique.dart';

/// Ouvre la fiche liée à une étape du planning (maquette : `ouvrirFiche`) : le prospect sur l'onglet Prospects,
/// le client sur l'onglet courant ; une étape administrative ou libre n'ouvre rien.
void ouvrirEtape(BuildContext context, EtapePlanning e) {
  final ref = e.ref;
  if (ref == null) return;
  switch (e.cible) {
    case CiblePlanning.prospect:
      AppRoutes.ficheProspect(context, ref, surOnglet: OngletApp.prospects);
    case CiblePlanning.client:
      AppRoutes.ficheMagasin(context, ref);
    case CiblePlanning.adm:
    case CiblePlanning.libre:
      break;
  }
}

/// Carte d'une étape de « Ma tournée du jour » du chef de secteur et du directeur (`carte` de `pageAccueil`).
///
/// La prochaine étape (la première pas encore faite) porte le contour d'accent, la pastille « Prochain » et le bouton
/// « Itinéraire ».
class CarteEtapeAccueil extends StatelessWidget {
  const CarteEtapeAccueil({
    super.key,
    required this.etape,
    required this.prochain,
  });

  final EtapePlanning etape;
  final bool prochain;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final fait = etape.fait;
    final (etatRond, glyphe, couleur) = prochain
        ? (EtatRond.prochain, '📍', u.violet)
        : fait
        ? (EtatRond.fait, '✓', AppColors.ok)
        : (EtatRond.normal, '🕒', AppColors.muted);
    final ligne = AppLigne(
      children: [
        Rond(
          etat: etatRond,
          child: Text(glyphe, style: AppText.t(16, c: couleur)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etape.titre, style: AppText.titreCarte),
              const SizedBox(height: 3),
              Text(detailEtape(etape), style: AppText.sousCarte),
            ],
          ),
        ),
        if (prochain)
          const Pastille('Prochain', variante: VariantePastille.violet)
        else
          Pastille(
            fait ? 'Fait' : 'À venir',
            variante: fait ? VariantePastille.vert : VariantePastille.gris,
          ),
      ],
    );
    return AppCarte(
      prochain: prochain,
      onTap: () => ouvrirEtape(context, etape),
      child: prochain
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ligne,
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AppBouton(
                    'Itinéraire',
                    petit: true,
                    onPressed: () => AppToast.show(
                      context,
                      "Ouverture de l'application de cartes (adresse renseignée).",
                    ),
                  ),
                ),
              ],
            )
          : ligne,
    );
  }
}
