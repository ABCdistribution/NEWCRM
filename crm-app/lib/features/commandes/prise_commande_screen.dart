import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/regles_commande.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';
import 'widgets/stock_widgets.dart';

/// Prise de commande (écran empilé `cmd`). Maquette : cmdEcran l.1598-1622. Sans `magasinId`, première étape :
/// choix du client. Ouverte par `AppRoutes.priseCommande(context, magasinId: ..., visiteId: ...)`.
///
/// L'écran démarre sa commande à l'ouverture (`startCommande`). `reprise` : la commande vient d'être reprise
/// depuis les commandes en attente, elle est déjà dans la saisie et ne doit pas être remise à zéro.
class PriseCommandeScreen extends ConsumerStatefulWidget {
  const PriseCommandeScreen({
    super.key,
    this.magasinId,
    this.visiteId,
    this.reprise = false,
  });

  final String? magasinId;
  final String? visiteId;
  final bool reprise;

  @override
  ConsumerState<PriseCommandeScreen> createState() =>
      _PriseCommandeScreenState();
}

class _PriseCommandeScreenState extends ConsumerState<PriseCommandeScreen> {
  final Object _jeton = Object();
  final TextEditingController _recherche = TextEditingController();

  /// Dernière commande de cet écran affichée.
  CommandeEnCours? _derniere;

  @override
  void initState() {
    super.initState();
    if (!widget.reprise) {
      // Hors de la construction des widgets : le store ne peut pas être modifié pendant `build`.
      Future.microtask(() {
        if (!mounted) return;
        ref
            .read(commandeEnCoursProvider.notifier)
            .demarrer(
              magasinId: widget.magasinId,
              visiteId: widget.visiteId,
              jeton: _jeton,
            );
      });
    }
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actuelle = ref.watch(commandeEnCoursProvider);
    final prete =
        actuelle != null &&
        (widget.reprise || identical(actuelle.jeton, _jeton));
    if (prete) _derniere = actuelle;
    // Une fois la commande validée ou mise en attente, l'écran garde son dernier contenu le temps de se refermer.
    final cmd = prete ? actuelle : _derniere;
    final Widget ecran;
    if (cmd == null) {
      ecran = const PageUnivers(
        entete: TopbarEcran(titre: 'Nouvelle commande'),
      );
    } else if (cmd.magasinId == null) {
      ecran = _ChoixClient(cmd: cmd);
    } else {
      ecran = _Catalogue(cmd: cmd, recherche: _recherche);
    }
    return ecran;
  }
}

/// Étape 1 sur 2 : choix du client parmi les clients actifs du profil.
class _ChoixClient extends ConsumerWidget {
  const _ChoixClient({required this.cmd});

  final CommandeEnCours cmd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magasins = ref.watch(magasinsProvider).where((m) => m.actif);
    return PageUnivers(
      entete: const TopbarEcran(
        titre: 'Nouvelle commande',
        sous: 'Étape 1 sur 2 · choisissez le client',
      ),
      enfants: [
        ListePaginee<Magasin>(
          elements: magasins.toList(),
          constructeur: (m) => AppCarte(
            onTap: () =>
                ref.read(commandeEnCoursProvider.notifier).choisirMagasin(m.id),
            child: AppLigne(
              alignement: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nom, style: AppText.titreCarte),
                      const SizedBox(height: 3),
                      Text(m.adresse, style: AppText.sousCarte),
                    ],
                  ),
                ),
                Text(
                  '›',
                  style: AppText.corps.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Étape 2 : catalogue avec stock, colisage, recherche, scan simulé et filtres ; barre « Voir le panier ».
class _Catalogue extends ConsumerWidget {
  const _Catalogue({required this.cmd, required this.recherche});

  final CommandeEnCours cmd;
  final TextEditingController recherche;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magasin = ref.watch(magasinParIdProvider(cmd.magasinId!));
    final notifier = ref.read(commandeEnCoursProvider.notifier);
    final produits = produitsProposes(
      q: cmd.q,
      cat: cmd.cat,
      masquer: cmd.masquer,
    );
    final n = cmd.nbArticles;
    return PageUnivers(
      entete: TopbarEcran(titre: 'Nouvelle commande', sous: magasin?.nom ?? ''),
      enfants: [
        BarreRecherche(
          hint: 'Nom, marque, réf. ou EAN',
          controller: recherche,
          onChanged: notifier.majRecherche,
          margeHaut: 14,
          actionsSup: [
            BoutonFiltre(
              icone: AppIcons.scan,
              semantique: 'Scanner un code-barres',
              onTap: () => AppRoutes.scannerProduit(context),
            ),
          ],
          nbFiltres: cmd.nbFiltres,
          onFiltres: () => AppRoutes.filtresPriseCommande(context),
        ),
        const SizedBox(height: 12),
        if (produits.isEmpty)
          const Vide('Aucun produit.')
        else
          ListePaginee<Produit>(
            elements: produits,
            constructeur: (p) =>
                LigneProduit(produit: p, ligne: cmd.ligne(p.id)),
          ),
      ],
      bas: BarreBasse.libre(
        blanc: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelleArticles(n), style: AppText.gras),
                  Text(
                    '${eurD(cmd.total)} HT',
                    style: AppText.t(12, c: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AppBouton(
              'Voir le panier ›',
              variante: VarianteBouton.plein,
              pleineLargeur: false,
              paddingH: 20,
              onPressed: () => AppRoutes.panierCommande(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne du catalogue de prise de commande : produit, stock, et selon le cas « ＋ Ajouter », compteur de
/// quantité ou « Remplacer › » (produit en rupture). `row` de cmdEcran.
class LigneProduit extends ConsumerWidget {
  const LigneProduit({super.key, required this.produit, required this.ligne});

  final Produit produit;

  /// Ligne du panier correspondante, nulle si le produit n'y est pas.
  final LigneCommande? ligne;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(commandeEnCoursProvider.notifier);
    final p = produit;
    final info = infoStock(p);
    final rupture = p.stock == NiveauStock.rupture;
    final trop = ligne != null && ligne!.qty > (p.qte ?? 0);
    final Widget action;
    if (rupture) {
      action = BoutonRemplacer(
        onTap: () => AppRoutes.produitsRemplacement(context, p.id),
      );
    } else if (ligne != null) {
      action = StepperQte(
        valeur: ligne!.qty,
        onMoins: () => notifier.retirer(p.id),
        onPlus: () => notifier.ajouter(p.id),
      );
    } else {
      action = AppBouton(
        '＋ Ajouter',
        petit: true,
        variante: VarianteBouton.plein,
        pleineLargeur: false,
        paddingH: 14,
        onPressed: () => notifier.ajouter(p.id),
      );
    }
    return AppCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLigne(
            alignement: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nom, style: AppText.titreCarte),
                    const SizedBox(height: 3),
                    Text(
                      '${p.marque} · Réf. ${p.code} · ${euros(p.prix ?? 0)} HT',
                      style: AppText.sousCarte,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LigneStock(info),
                    ),
                  ],
                ),
              ),
              action,
            ],
          ),
          if (rupture && (p.reappro ?? '').isNotEmpty)
            Astuce('Le produit sera disponible à partir du ${p.reappro}'),
          if (trop)
            ErreurStock(
              texte:
                  'Stock insuffisant : ${p.qte} disponibles pour ${ligne!.qty} demandés.',
              lien: 'Compléter avec un remplacement ›',
              onLien: () => AppRoutes.produitsRemplacement(context, p.id),
            ),
        ],
      ),
    );
  }
}
