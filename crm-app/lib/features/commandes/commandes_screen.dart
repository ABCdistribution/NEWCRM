import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/liste_commandes.dart';
import 'panier_screen.dart';
import 'prise_commande_screen.dart';
import 'state/attente_provider.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';
import 'state/filtres_commandes.dart';

/// Onglet « Commandes » (promoteur) : commandes en attente, compteurs pas livrées / livrées, cartes de suivi de
/// livraison, recherche et filtres. Maquette : salesCommandes l.1204-1211, commandesListe l.1198-1203,
/// sectionAttente l.1188-1197, carteLivraison l.1098-1102.
class CommandesScreen extends ConsumerStatefulWidget {
  const CommandesScreen({super.key});

  @override
  ConsumerState<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends ConsumerState<CommandesScreen> {
  late final TextEditingController _recherche = TextEditingController(
    text: ref.read(filtresCommandesProvider).q,
  );

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// `att-reprendre` : la commande revient dans la saisie et l'on ouvre directement le panier, par-dessus la
  /// prise de commande (la pile de la maquette est `cmd` puis `cmd-panier`).
  void _reprendre(CommandeEnAttente a, int rang) {
    ref.read(commandeEnCoursProvider.notifier).reprendre(a, rang);
    final navigateur = Navigator.of(context);
    navigateur.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'cmd'),
        builder: (_) => const PriseCommandeScreen(reprise: true),
      ),
    );
    navigateur.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'cmd-panier'),
        builder: (_) => const PanierScreen(),
      ),
    );
  }

  /// `att-suppr`.
  void _supprimer(int rang) {
    ref.read(attenteProvider.notifier).retirer(rang);
    AppToast.show(context, 'Commande en attente supprimée.');
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleActifProvider);
    final etat = ref.watch(crmProvider);
    final f = ref.watch(filtresCommandesProvider);
    final attentes = ref.watch(attenteProvider);
    final liste = commandesListe(etat, f);
    final base = commandesListe(etat, f, ignorerEtat: true);
    int nb(StatutLivraison s) => base.where((c) => c.statut == s).length;
    final visibles = [
      for (var i = 0; i < attentes.length; i++)
        if (etat.aMagasin(attentes[i].magasinId)) (a: attentes[i], rang: i),
    ];
    final sous =
        '${f.portee == PorteeCommandes.mes ? 'Mes commandes' : 'Toutes les commandes ${porteeTexte(role)}'}'
        ' · ${liste.length} résultat${liste.length > 1 ? 's' : ''}';
    return PageUnivers(
      entete: AppEntete(
        titre: 'Commandes',
        sous: sous,
        extra: BarreRecherche(
          hint: 'Client, n° de commande…',
          controller: _recherche,
          onChanged: (q) => ref
              .read(filtresCommandesProvider.notifier)
              .maj((x) => x.copyWith(q: q)),
          nbFiltres: f.nbActifs(role),
          onFiltres: () => AppRoutes.filtresCommandes(context),
        ),
      ),
      enfants: [
        if (visibles.isNotEmpty) ...[
          _TitreAttente(visibles.length),
          for (final v in visibles)
            _CarteAttente(
              a: v.a,
              onReprendre: () => _reprendre(v.a, v.rang),
              onSupprimer: () => _supprimer(v.rang),
            ),
          const SizedBox(height: 6),
        ],
        KpiRangee([
          KpiItem('Pas livrées', '${nb(StatutLivraison.pasLivree)}'),
          KpiItem('Livrées', '${nb(StatutLivraison.livree)}'),
        ]),
        if (liste.isEmpty)
          const Vide('Aucune commande pour ces filtres.')
        else
          for (final c in liste) CarteLivraison(c),
      ],
    );
  }
}

/// « Commandes en attente » et son compteur (`titre-ligne` aux marges 4 / 2 / 10 et titre de 16 px).
class _TitreAttente extends StatelessWidget {
  const _TitreAttente(this.nombre);

  final int nombre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Commandes en attente',
              style: AppText.t(16, w: FontWeight.w800),
            ),
          ),
          Pastille('$nombre'),
        ],
      ),
    );
  }
}

/// Une commande mise de côté : client, contenu, consigne de livraison, note, « Reprendre » et « Supprimer ».
class _CarteAttente extends ConsumerWidget {
  const _CarteAttente({
    required this.a,
    required this.onReprendre,
    required this.onSupprimer,
  });

  final CommandeEnAttente a;
  final VoidCallback onReprendre;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magasin = ref.watch(magasinParIdProvider(a.magasinId));
    final u = context.univers;
    final n = a.lignes.length;
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
                    Text(
                      magasin?.nom ?? a.magasinId,
                      style: AppText.titreCarte,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$n référence${n > 1 ? 's' : ''} · ${a.nbArticles} articles · ${eurD(a.total)} HT',
                      style: AppText.sousCarte,
                    ),
                  ],
                ),
              ),
              const Pastille('⏸ En attente'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Mise de côté le ${a.date} · non envoyée',
              style: AppText.t(12, c: AppColors.muted),
            ),
          ),
          if (a.pas)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⏳ Ne pas livrer avant le ${dateFr(a.dateMin)}'
                '${a.motifPas.isNotEmpty ? ' · ${motifFinal(a.motifPas, a.motifAutre)}' : ''}',
                style: AppText.t(12.5, w: FontWeight.w700, c: u.bleu),
              ),
            ),
          if (a.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📝 ${a.note}', style: AppText.t(12.5)),
            ),
          Rangee(
            margeHaut: 10,
            children: [
              AppBouton(
                'Reprendre',
                petit: true,
                variante: VarianteBouton.plein,
                onPressed: onReprendre,
              ),
              AppBouton(
                'Supprimer',
                petit: true,
                variante: VarianteBouton.danger,
                onPressed: onSupprimer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
