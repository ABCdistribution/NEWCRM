import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/data/activite_serveur.dart';
import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'accueil_logique.dart';
import 'widgets/bloc_livraisons.dart';

/// Accueil du promoteur (maquette : `salesAccueil` l.1138-1156) : tuiles « Visites » et « CA / objectif du mois »,
/// bouton « Nouvelle commande », suivi des livraisons, tournée du jour et brouillons de visite.
class AccueilPromoteur extends ConsumerWidget {
  const AccueilPromoteur({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(crmProvider);
    // Connecté : activité du mois donnée par le CRM (sans objectif, la barre reste vide). Démonstration : maquette.
    final connecte = ref.watch(sessionProvider) != null;
    final perf = performanceServeur();
    final moi = connecte ? null : promoteurParNom(etat.nomProfil)!;
    final ca = connecte ? (perf?.ca ?? 0) : moi!.real;
    final cible = connecte ? (perf?.cible ?? 0) : moi!.cible;
    final lignes = lignesTournee(etat);
    final realisees = lignes
        .where((l) => l.etat == EtatTournee.realisee)
        .length;
    final brouillons = etat.visites
        .where((v) => v.etat == EtatVisite.brouillon)
        .toList();
    return PageUnivers(
      entete: AppEntete.libre(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BandeauBonjour(),
            TuilesRangee([
              if (connecte)
                Tuile(
                  libelle: 'Visites du mois',
                  valeur: '${perf?.visites ?? 0}',
                )
              else
                Tuile(
                  libelle: 'Visites',
                  valeur: '$realisees',
                  complement: '/ ${lignes.length}',
                ),
              Tuile(
                flex: 2,
                libelle: 'CA / objectif du mois',
                valeur: eur(ca),
                complement: '/ ${eur(cible)}',
                tailleValeur: 19,
                tailleComplement: 13,
                poidsComplement: FontWeight.w600,
                opaciteComplement: 0.7,
                child: BarreObjectif(real: ca, cible: cible),
              ),
            ]),
          ],
        ),
      ),
      enfants: [
        AppBouton(
          '＋ Nouvelle commande',
          variante: VarianteBouton.plein,
          onPressed: () => AppRoutes.priseCommande(context),
        ),
        const SizedBox(height: 12),
        BlocLivraisons(livraisons: livraisonsEnCours(etat)),
        if (!connecte || lignes.isNotEmpty)
          const TitreLigne('Ma tournée du jour', taille: 18),
        for (final l in lignes) _CarteTournee(ligne: l),
        if (brouillons.isNotEmpty) ...[
          const TitreLigne('Brouillons', taille: 16, margeHaut: 18),
          for (final v in brouillons)
            AppCarte(
              onTap: () => AppRoutes.visite(context, v.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etat.magasinParId(v.magasinId)?.nom ?? v.magasinId,
                    style: AppText.titreCarte,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Visite en cours · brouillon sur ce téléphone',
                    style: AppText.sousCarte,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Aspect d'une étape de la tournée selon son état (maquette : `PUCE`) : pastille, libellé, glyphe, fond du rond.
({String libelle, VariantePastille variante, String glyphe, Color fond}) _puce(
  EtatTournee e,
) => switch (e) {
  EtatTournee.realisee => (
    libelle: 'Réalisée',
    variante: VariantePastille.vert,
    glyphe: '✅',
    fond: const Color(0xFFDDF5E6),
  ),
  EtatTournee.enCours => (
    libelle: 'En cours',
    variante: VariantePastille.bleu,
    glyphe: '▶',
    fond: const Color(0xFFDFE8FF),
  ),
  EtatTournee.aFaire => (
    libelle: 'À faire',
    variante: VariantePastille.gris,
    glyphe: '🕒',
    fond: const Color(0xFFEDEFF3),
  ),
};

/// Carte d'une visite de « Ma tournée du jour » : un appui ouvre (ou démarre) la visite chez le client ; le bouton
/// « Démarrer la visite » est proposé sur la première visite à faire, « Reprendre la visite » sur celle en cours.
class _CarteTournee extends StatelessWidget {
  const _CarteTournee({required this.ligne});

  final LigneTournee ligne;

  @override
  Widget build(BuildContext context) {
    final puce = _puce(ligne.etat);
    final enCours = ligne.etat == EtatTournee.enCours;
    void ouvrir() => AppRoutes.demarrerVisite(context, ligne.magasin.id);
    return AppCarte(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ouvrir,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AppLigne(
                alignement: CrossAxisAlignment.center,
                children: [
                  Rond(
                    taille: 46,
                    rayon: 14,
                    fond: puce.fond,
                    child: Text(
                      puce.glyphe,
                      style: AppText.t(16, c: AppColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ligne.magasin.nom,
                          style: AppText.t(15, w: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (ligne.visite.heure.isNotEmpty) ligne.visite.heure,
                            ligne.visite.type,
                          ].join(' · '),
                          style: AppText.sousCarte,
                        ),
                      ],
                    ),
                  ),
                  Pastille(puce.libelle, variante: puce.variante),
                ],
              ),
            ),
          ),
          if (enCours || ligne.demarrer)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AppBouton(
                enCours ? 'Reprendre la visite' : 'Démarrer la visite',
                petit: true,
                variante: VarianteBouton.plein,
                onPressed: ouvrir,
              ),
            ),
        ],
      ),
    );
  }
}
