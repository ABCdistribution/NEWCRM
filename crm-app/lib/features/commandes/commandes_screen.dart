import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'commande_actions.dart';
import 'logic/attente_crm.dart';
import 'logic/liste_commandes.dart';
import 'panier_screen.dart';
import 'prise_commande_screen.dart';
import 'state/attente_provider.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';
import 'state/filtres_commandes.dart';
import 'state/sous_onglet_commandes.dart';

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
  void initState() {
    super.initState();
    // Les commandes en attente du CRM sont rafraîchies à l'ouverture de l'écran (la copie locale s'affiche d'abord).
    Future.microtask(_actualiserAttentes);
  }

  void _actualiserAttentes() {
    if (!mounted || !ref.read(attenteCrmActiveProvider)) return;
    ref.read(commandesAttenteSynchroProvider.notifier).rafraichir();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// Ouvre une commande en attente du CRM : elle revient dans la prise de commande, le panier par-dessus.
  void _ouvrir(CommandeAttenteCrm a) {
    ref.read(commandeEnCoursProvider.notifier).reprendreCrm(a);
    _empilerPanier();
  }

  /// Suppression (après confirmation) d'une commande en attente du CRM.
  Future<void> _supprimerCrm(CommandeAttenteCrm a) async {
    final ok = await showConfirmation(
      context,
      titre: 'Supprimer cette commande ?',
      texte: 'La commande en attente sera supprimée du CRM.',
      ok: 'Supprimer',
    );
    if (ok != true || !mounted) return;
    final erreur = await supprimerCommandeEnAttente(
      ProviderScope.containerOf(context),
      a.id,
    );
    if (!mounted) return;
    AppToast.show(context, erreur ?? 'Commande en attente supprimée.');
  }

  /// `att-reprendre` : la commande revient dans la saisie et l'on ouvre directement le panier, par-dessus la
  /// prise de commande (la pile de la maquette est `cmd` puis `cmd-panier`).
  void _reprendre(CommandeEnAttente a, int rang) {
    ref.read(commandeEnCoursProvider.notifier).reprendre(a, rang);
    _empilerPanier();
  }

  void _empilerPanier() {
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
    final crmActif = ref.watch(attenteCrmActiveProvider);
    final attentesCrm = ref.watch(attentesCrmProvider);
    final onglet = ref.watch(sousOngletCommandesProvider);
    final surAttente = crmActif && onglet == SousOngletCommandes.attente;
    // Promoteur connecté : l'attente locale de démonstration n'a pas cours, celle du CRM la remplace.
    final attentes = crmActif
        ? const <CommandeEnAttente>[]
        : ref.watch(attenteProvider);
    final liste = commandesListe(etat, f);
    final base = commandesListe(etat, f, ignorerEtat: true);
    int nb(StatutLivraison s) => base.where((c) => c.statut == s).length;
    final visibles = [
      for (var i = 0; i < attentes.length; i++)
        if (etat.aMagasin(attentes[i].magasinId)) (a: attentes[i], rang: i),
    ];
    final sous = surAttente
        ? '${attentesCrm.length} commande${attentesCrm.length > 1 ? 's' : ''} en attente'
        : '${f.portee == PorteeCommandes.mes ? 'Mes commandes' : 'Toutes les commandes ${porteeTexte(role)}'}'
              ' · ${liste.length} résultat${liste.length > 1 ? 's' : ''}';
    return PageUnivers(
      entete: AppEntete(
        titre: 'Commandes',
        sous: sous,
        extra: surAttente
            ? null
            : BarreRecherche(
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
        if (crmActif)
          Segment(
            libelles: ['Suivi', 'En attente (${attentesCrm.length})'],
            index: onglet.index,
            ton: TonSelection.bleu,
            onChanged: (i) {
              ref
                  .read(sousOngletCommandesProvider.notifier)
                  .choisir(SousOngletCommandes.values[i]);
              if (i == SousOngletCommandes.attente.index) _actualiserAttentes();
            },
          ),
        if (surAttente) ...[
          if (attentesCrm.isEmpty)
            const Vide('Aucune commande en attente.')
          else
            for (final a in attentesCrm)
              _CarteAttenteCrm(
                a: a,
                onOuvrir: () => _ouvrir(a),
                onSupprimer: () => _supprimerCrm(a),
              ),
        ] else ...[
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

/// Une commande en attente du CRM : magasin, date, contenu et total indicatif ; un appui l'ouvre pour la modifier.
class _CarteAttenteCrm extends ConsumerWidget {
  const _CarteAttenteCrm({
    required this.a,
    required this.onOuvrir,
    required this.onSupprimer,
  });

  final CommandeAttenteCrm a;
  final VoidCallback onOuvrir;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magasin = ref.watch(magasinParIdProvider(a.clientId));
    final n = a.nbLignes;
    final date = a.date;
    return AppCarte(
      onTap: onOuvrir,
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
                    NomMagasin(
                      magasin?.nom ?? a.clientNom,
                      classe: magasin?.classe ?? a.clientClasse,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${date == null ? '' : '${libelleDateAttente(date)} · '}'
                      '$n ligne${n > 1 ? 's' : ''} · ${eurD(a.totalIndicatif)} HT',
                      style: AppText.sousCarte,
                    ),
                  ],
                ),
              ),
              const Pastille('⏸ En attente'),
            ],
          ),
          if (a.envoyee || a.nePasLivrerAvant != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (a.nePasLivrerAvant != null)
                    Pastille(
                      '⏳ pas avant ${libelleJourMois(a.nePasLivrerAvant!)}',
                      variante: VariantePastille.jaune,
                    ),
                  if (a.envoyee)
                    Pastille(
                      '✉ Envoyée à ${a.emailValidation ?? 'le client'}',
                      variante: VariantePastille.bleu,
                    ),
                ],
              ),
            ),
          Rangee(
            margeHaut: 10,
            children: [
              AppBouton(
                'Modifier',
                petit: true,
                variante: VarianteBouton.plein,
                onPressed: onOuvrir,
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
                    NomMagasin(
                      magasin?.nom ?? a.magasinId,
                      classe: magasin?.classe,
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
