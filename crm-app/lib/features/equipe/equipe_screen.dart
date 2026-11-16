import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/data/equipe_serveur.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/equipe_demo.dart';
import 'state/equipe_state.dart';
import 'state/filtres.dart';
import 'widgets/lignes_equipe.dart';

/// Onglet « Mon équipe » (chef de secteur, directeur ; menu « + »). Maquette : pageEquipePilot l.933-950.
///
/// Chef de secteur : les promoteurs de son secteur. Directeur : ses chefs de secteur ou leurs promoteurs, selon le
/// filtre de la feuille « Filtres » (`AppRoutes.filtresEquipe`). Lecture seule : un appui ouvre la page du chef de
/// secteur ou du promoteur.
class EquipeScreen extends ConsumerWidget {
  const EquipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    return role == Role.cs
        ? const _EquipeChefSecteur()
        : const _EquipeDirecteur();
  }
}

/// Le chef de secteur voit les promoteurs de son secteur (Nadia H., secteur « Île-de-France »).
class _EquipeChefSecteur extends ConsumerWidget {
  const _EquipeChefSecteur();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Connecté : le chef de secteur est l'utilisateur lui-même ; démonstration : Nadia H.
    final moi = ref.watch(sessionProvider)?.id;
    final chefs = chefsActuels();
    final chef =
        chefs.where((c) => c.id == moi).firstOrNull ?? chefs.firstOrNull;
    final promoteurs = chef == null
        ? const <Promoteur>[]
        : promoteursDuChef(chef.id);
    return PageUnivers(
      entete: AppEntete(
        titre: 'Mon équipe',
        tailleTitre: 24,
        sous: '${promoteurs.length} promoteurs · ${chef?.secteur ?? ''}',
      ),
      enfants: [
        for (final p in promoteurs)
          LignePromoteur(
            promoteur: p,
            avecJour: !p.reel,
            onTap: () => AppRoutes.pagePromoteur(
              context,
              csId: chef?.id ?? 'n',
              nom: p.nom,
            ),
          ),
        const Pied(
          'Touchez un promoteur pour voir ses visites et ses commandes.',
          centre: true,
          margeHaut: 0,
        ),
      ],
    );
  }
}

class _EquipeDirecteur extends ConsumerWidget {
  const _EquipeDirecteur();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtresEquipeProvider);
    final chefs = [
      for (final c in chefsActuels())
        if (f.region == regionToutes || c.region == f.region) c,
    ];
    final voirChefs = f.type == TypeEquipe.chefsSecteur;
    final nbPro = chefs.fold<int>(
      0,
      (a, c) => a + promoteursDuChef(c.id).length,
    );
    final promoteurs = [
      for (final c in chefs)
        for (final p in promoteursDuChef(c.id)) (c: c, p: p),
    ];
    final vide = voirChefs ? chefs.isEmpty : promoteurs.isEmpty;

    return PageUnivers(
      entete: AppEntete(
        titre: 'Mon équipe',
        tailleTitre: 24,
        sous:
            '${chefs.length} chef${chefs.length > 1 ? 's' : ''} de secteur · $nbPro promoteurs${f.region != regionToutes ? ' · ${f.region}' : ''}',
        extra: BarreFiltres(
          resume: f.libelle,
          nbFiltres: f.nb,
          onFiltres: () => AppRoutes.filtresEquipe(context),
        ),
      ),
      enfants: [
        if (voirChefs) ...[
          TitreCompte('Chefs de secteur', '${chefs.length}'),
          for (final c in chefs)
            _CarteChefSecteur(
              chef: c,
              onTap: () => AppRoutes.pageChefSecteur(context, c.id),
            ),
          if (chefs.isEmpty)
            const Vide('Aucun chef de secteur pour ce filtre.'),
        ] else ...[
          TitreCompte('Promoteurs', '$nbPro'),
          for (final x in promoteurs)
            LignePromoteur(
              promoteur: x.p,
              chef: x.c.nom,
              avecJour: !x.p.reel,
              onTap: () =>
                  AppRoutes.pagePromoteur(context, csId: x.c.id, nom: x.p.nom),
            ),
          if (promoteurs.isEmpty) const Vide('Aucun promoteur pour ce filtre.'),
        ],
        // Une carte précède le pied : sa marge basse (10) absorbe la marge haute du pied (6).
        Pied(
          'Touchez un chef de secteur ou un promoteur pour voir son activité (lecture seule).',
          centre: true,
          margeHaut: vide ? 6 : 0,
        ),
      ],
    );
  }
}

/// Carte d'un chef de secteur dans la liste du directeur : région, secteur, prévision enregistrée ou non, rapport en cours.
class _CarteChefSecteur extends StatelessWidget {
  const _CarteChefSecteur({required this.chef, required this.onTap});

  final ChefSecteur chef;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = chef;
    if (c.reel) {
      return AppCarte(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarUtilisateur(
                  c.id,
                  c.ini,
                  taille: 40,
                  fond: const Color(0xFFE7E0F7),
                  texte: context.univers.violet,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nom, style: AppText.titreCarte),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${c.region} · Secteur ${c.secteur} · ${promoteursDuChef(c.id).length} promoteurs',
                          style: AppText.sousCarte,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Chiffres(margeHaut: 8, [
              Chiffre('${c.visites}', 'visites du mois'),
              Chiffre('${c.commandes}', 'commandes'),
              Chiffre(eur(c.ca), 'de CA'),
            ]),
          ],
        ),
      );
    }
    final detail = detailChefSecteur(c.id);
    final rap = detail.rap;
    final u = context.univers;
    return AppCarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarUtilisateur(
                c.reel ? c.id : null,
                c.ini,
                taille: 40,
                fond: const Color(0xFFE7E0F7),
                texte: u.violet,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nom, style: AppText.titreCarte),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${c.region} · Secteur ${c.secteur} · ${promoteursDuChef(c.id).length} promoteurs',
                        style: AppText.sousCarte,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (detail.prev != null)
                  const Pastille(
                    'Prévision enregistrée',
                    variante: VariantePastille.vert,
                  )
                else
                  const Pastille('Prévision non renseignée'),
                const Pastille(
                  'Rapport en cours',
                  variante: VariantePastille.jaune,
                ),
              ],
            ),
          ),
          Chiffres(
            margeHaut: 8,
            rap != null
                ? [
                    Chiffre('${rap.pct} %', 'du prévu à ce jour'),
                    Chiffre('', resumeEcarts(rap.ecarts.map((e) => e.genre))),
                  ]
                : [
                    const Chiffre(
                      '',
                      'Pas de comparaison possible cette semaine',
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
