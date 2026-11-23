import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/state/state.dart';
import '../../../core/sync/detail_prospect_provider.dart';
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
class CarteEtapeAccueil extends ConsumerWidget {
  const CarteEtapeAccueil({
    super.key,
    required this.etape,
    required this.prochain,
  });

  final EtapePlanning etape;
  final bool prochain;

  /// Adresse de l'étape : celle de la soirée, sinon le magasin ou le prospect visé ; nulle si le CRM n'en donne pas.
  String? _adresse(WidgetRef ref) {
    final soiree = etape.soireeAdr?.trim();
    if (soiree != null && soiree.isNotEmpty) return soiree;
    final id = etape.ref;
    if (id == null) return null;
    switch (etape.cible) {
      case CiblePlanning.client:
        return ref.watch(magasinParIdProvider(id))?.adresse;
      case CiblePlanning.prospect:
        final p = ref.watch(prospectParIdProvider(id));
        if (p == null) return null;
        final detail = ref.watch(detailProspectProvider(id)).value;
        return detail?.adresse ?? (p.cp.isEmpty ? null : p.cp);
      case CiblePlanning.adm:
      case CiblePlanning.libre:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = context.univers;
    final fait = etape.fait;
    final (etatRond, glyphe, couleur) = prochain
        ? (EtatRond.prochain, '📍', u.violet)
        : fait
        ? (EtatRond.fait, '✓', AppColors.ok)
        : (EtatRond.normal, '🕒', AppColors.muted);
    // Adresse de l'étape : soirée, sinon magasin ou prospect visé ; sans adresse, pas d'itinéraire.
    final carte = prochain ? uriItineraire(_adresse(ref)) : null;
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
      child: carte != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ligne,
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AppBouton(
                    'Itinéraire',
                    petit: true,
                    onPressed: () => lancerExterne(
                      context,
                      ref.read(lanceurExterneProvider),
                      carte,
                    ),
                  ),
                ),
              ],
            )
          : ligne,
    );
  }
}
