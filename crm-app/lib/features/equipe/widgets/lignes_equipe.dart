/// Éléments d'affichage communs aux écrans du lot « équipe » : ligne de promoteur (`ligneProm`), carte de semaine,
/// liste d'écarts (`ecartsListe`), cartes de visite et de commande en lecture seule, sélecteur de filtres.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/equipe_demo.dart';

/// Corps d'un écran empilé sous sa barre supérieure (`<div class="corps" style="padding-top:4px">`) : marges 4 / 16 / 24.
class CorpsSousTopbar extends StatelessWidget {
  const CorpsSousTopbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Titre de section de 18 px avec un texte gris à droite (`.titre-ligne` + `<span>` de 12,5 px).
///
/// Comme les éléments flex de la maquette, les deux textes rétrécissent et passent à la ligne quand ils ne tiennent
/// pas côte à côte ; leur part de la largeur est proportionnelle à leur longueur.
class TitreCompte extends StatelessWidget {
  const TitreCompte(this.titre, this.compte, {super.key, this.margeHaut = 0});

  final String titre;
  final String compte;
  final double margeHaut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: margeHaut, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: titre.length * 18,
          child: Text(
            titre,
            style: AppText.titreSection.copyWith(fontSize: 18),
          ),
        ),
        Flexible(
          flex: (compte.length * 12.5).round(),
          child: Text(compte, style: AppText.t(12.5, c: AppColors.muted)),
        ),
      ],
    ),
  );
}

/// Barre `.barre-rech` sans champ de recherche : un sélecteur qui résume les filtres et le bouton filtre.
class BarreFiltres extends StatelessWidget {
  const BarreFiltres({
    super.key,
    required this.resume,
    required this.nbFiltres,
    required this.onFiltres,
  });

  final String resume;
  final int nbFiltres;
  final VoidCallback onFiltres;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      children: [
        Expanded(child: Selecteur(resume, onTap: onFiltres, ombre: false)),
        const SizedBox(width: 10),
        BoutonFiltre(onTap: onFiltres, nbFiltres: nbFiltres),
      ],
    ),
  );
}

/// Carte d'un promoteur (`ligneProm`) : avatar, clients et visites de la semaine, CA réalisé sur objectif avec sa barre ;
/// `avecJour` ajoute le point sur la tournée du jour. `chef` suffixe le nom du chef de secteur (liste « Promoteurs »).
class LignePromoteur extends StatelessWidget {
  const LignePromoteur({
    super.key,
    required this.promoteur,
    required this.onTap,
    this.avecJour = false,
    this.chef,
  });

  final Promoteur promoteur;
  final VoidCallback onTap;
  final bool avecJour;
  final String? chef;

  @override
  Widget build(BuildContext context) {
    final p = promoteur;
    final u = context.univers;
    final couleur = couleurObjectif(p.obj);
    final faites = p.jour
        .where((j) => j.etat == EtatTourneePromo.realisee)
        .length;
    final enVisite = p.jour
        .where((j) => j.etat == EtatTourneePromo.enCours)
        .firstOrNull;
    return AppCarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLigne(
            alignement: CrossAxisAlignment.center,
            children: [
              AvatarUtilisateur(
                p.userId,
                p.ini,
                taille: 40,
                fond: AppColors.pBleuFond,
                texte: AppColors.pBleuTexte,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: p.nom,
                        children: [
                          if (chef != null)
                            TextSpan(
                              text: ' · $chef',
                              style: AppText.t(
                                11.5,
                                w: FontWeight.w600,
                                c: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                      style: AppText.titreCarte,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${p.mag} clients · ${p.v}/${p.p} visites cette semaine',
                        style: AppText.sousCarte,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eur(p.real),
                    style: AppText.t(16, w: FontWeight.w700, c: couleur),
                  ),
                  Text(
                    'sur ${eur(p.cible)}',
                    style: AppText.t(11, c: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          BarreProgression(
            valeur: math.min(100, p.obj) / 100,
            couleur: couleur,
          ),
          if (avecJour)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Aujourd'hui : $faites/${p.jour.length} visites faites",
                      style: AppText.t(12, c: AppColors.muted),
                    ),
                  ),
                  if (p.obj < 70)
                    Text(
                      "En retard sur l'objectif",
                      style: AppText.t(
                        12,
                        w: FontWeight.w700,
                        c: AppColors.alert,
                      ),
                    )
                  else if (enVisite != null)
                    Flexible(
                      child: Text(
                        'En visite · ${enVisite.client}',
                        textAlign: TextAlign.right,
                        style: AppText.t(12, w: FontWeight.w700, c: u.bleu),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte d'une semaine du rapport d'un chef de secteur : numéro, période, état, puis le prévu réalisé et les écarts.
class CarteSemaine extends StatelessWidget {
  const CarteSemaine({super.key, required this.semaine, required this.onTap});

  final SemaineCs semaine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = semaine;
    return AppCarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semaine ${w.n}${w.enCours ? ' · en cours' : ''}',
                      style: AppText.titreCarte,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(w.periode, style: AppText.sousCarte),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              pastilleSemaine(w),
            ],
          ),
          if (w.nonRenseignee)
            const Pied('Prévision non renseignée : pas de comparaison')
          else
            Chiffres(margeHaut: 8, [
              Chiffre('${w.pct} %', 'du prévu'),
              Chiffre('', resumeEcarts(w.ecarts.map((e) => e.genre))),
            ]),
        ],
      ),
    );
  }
}

/// Liste d'écarts triés (`ecartsListe`) : un rond coloré, le titre et « libellé · détail ».
class ListeEcarts extends StatelessWidget {
  const ListeEcarts(this.ecarts, {super.key});

  final List<EcartPlanning> ecarts;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final e in ecartsTries(ecarts))
        LigneEcart(
          titre: e.titre,
          detail: e.sousTitre,
          symbole: stylesEcart[e.genre]!.symbole,
          fond: Color(stylesEcart[e.genre]!.fond),
          texte: Color(stylesEcart[e.genre]!.texte),
        ),
    ],
  );
}

/// Ligne de la prévision enregistrée : le jour dans le rond gris, le titre, « jour heure ».
class LignePrevisionEnregistree extends StatelessWidget {
  const LignePrevisionEnregistree(this.ligne, {super.key});

  final LignePrevision ligne;

  @override
  Widget build(BuildContext context) => LigneEcart(
    titre: ligne.titre,
    detail: ligne.quand,
    symbole: ligne.jour,
    fond: AppColors.ecartGrisFond,
    texte: AppColors.ecartGrisTexte,
  );
}

/// Carte de visite en lecture seule (`carteVisiteRO`) : client, détail, pastille « En cours » ou « Envoyée ».
class CarteVisiteLecture extends StatelessWidget {
  const CarteVisiteLecture({
    super.key,
    required this.client,
    required this.detail,
    required this.enCours,
  });

  final String client;
  final String detail;
  final bool enCours;

  @override
  Widget build(BuildContext context) => _CarteLecture(
    titre: client,
    detail: detail,
    pastille: Pastille(
      enCours ? 'En cours' : 'Envoyée',
      variante: enCours ? VariantePastille.bleu : VariantePastille.vert,
    ),
  );
}

/// Carte de commande en lecture seule (`carteCmdRO`) : montant HT, détail, statut de livraison.
class CarteCommandeLecture extends StatelessWidget {
  const CarteCommandeLecture({
    super.key,
    required this.ht,
    required this.detail,
    required this.statut,
  });

  final String ht;
  final String detail;
  final StatutLivraison statut;

  @override
  Widget build(BuildContext context) => _CarteLecture(
    titre: '$ht HT',
    detail: detail,
    pastille: Pastille(
      statut.libelle,
      variante: statut == StatutLivraison.livree
          ? VariantePastille.vert
          : VariantePastille.jaune,
    ),
  );
}

class _CarteLecture extends StatelessWidget {
  const _CarteLecture({
    required this.titre,
    required this.detail,
    required this.pastille,
  });

  final String titre;
  final String detail;
  final Widget pastille;

  @override
  Widget build(BuildContext context) => AppCarte(
    child: AppLigne(
      alignement: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: AppText.titreCarte),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(detail, style: AppText.sousCarte),
              ),
            ],
          ),
        ),
        pastille,
      ],
    ),
  );
}

/// Pastille d'état d'une semaine de rapport : « En cours », « Non validé », « Validé auto » ou « Validé ».
Pastille pastilleSemaine(SemaineCs w) {
  if (w.enCours) return const Pastille('En cours', variante: VariantePastille.jaune);
  if (w.nonValide) {
    return const Pastille('Non validé', variante: VariantePastille.jaune);
  }
  return w.auto
      ? const Pastille('Validé auto', variante: VariantePastille.gris)
      : const Pastille('Validé', variante: VariantePastille.vert);
}
