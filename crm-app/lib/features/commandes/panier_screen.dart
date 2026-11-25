import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'commande_actions.dart';
import 'envoi_mail_sheet.dart';
import 'logic/regles_commande.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';
import 'state/sous_onglet_commandes.dart';
import 'widgets/stock_widgets.dart';

/// Panier de la commande en cours (écran empilé `cmd-panier`). Maquette : cmdPanier l.1624-1642.
/// Ouvert par `AppRoutes.panierCommande(context)`.
///
/// Lignes avec quantités et stock, total HT, consigne « Ne pas livrer avant », remarque pour l'ADV,
/// « Mettre en attente » et « Valider ».
class PanierScreen extends ConsumerStatefulWidget {
  const PanierScreen({super.key});

  @override
  ConsumerState<PanierScreen> createState() => _PanierScreenState();
}

class _PanierScreenState extends ConsumerState<PanierScreen> {
  /// Dernière commande affichée : à la validation la commande en cours disparaît du store pendant que l'écran
  /// se referme, il continue alors d'afficher son contenu au lieu de se vider sous les yeux.
  CommandeEnCours? _derniere;

  @override
  Widget build(BuildContext context) {
    final cmd =
        ref.watch(commandeEnCoursProvider) ??
        _derniere ??
        const CommandeEnCours();
    _derniere = cmd;
    final magasin = cmd.magasinId == null
        ? null
        : ref.watch(magasinParIdProvider(cmd.magasinId!));
    final notifier = ref.read(commandeEnCoursProvider.notifier);
    final n = cmd.lignes.length;
    final crmActif = ref.watch(attenteCrmActiveProvider);
    final livraison = cmd.pas && cmd.dateMin.isNotEmpty
        ? 'à partir du ${dateFr(cmd.dateMin)}'
        : DemoTemps.livraisonPrevue;
    return PageUnivers(
      entete: TopbarEcran(
        titre: 'Panier',
        sous: magasin?.nom,
        classe: magasin?.classe,
        droite: ConstrainedBox(
          // Largeur naturelle d'environ 170 px ; le plafond protège la ligne si la police ou l'échelle de texte grossit.
          constraints: const BoxConstraints(maxWidth: 210),
          child: _BoutonAjouterArticles(
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      enfants: [
        if (cmd.lignes.isEmpty)
          const Vide('Le panier est vide.')
        else
          for (final l in cmd.lignes) _LignePanier(ligne: l),
        AppCarte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$n référence${n > 1 ? 's' : ''} · ${cmd.nbArticles} articles',
                style: AppText.t(16, c: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total HT',
                      style: AppText.t(15, w: FontWeight.w700),
                    ),
                  ),
                  Text(
                    eurD(cmd.total),
                    style: AppText.t(17, w: FontWeight.w700),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '🚚 Livraison estimée $livraison',
                  style: AppText.t(12, c: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        AppCarte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CaseConsigne(
                cochee: cmd.pas,
                onTap: () {
                  if (notifier.basculerConsigne()) {
                    AppRoutes.nePasLivrerAvant(context);
                  }
                },
              ),
              if (cmd.pas && cmd.dateMin.isNotEmpty)
                EncadreConsigne(
                  titre: '⏳ Ne pas livrer avant le ${dateFr(cmd.dateMin)}',
                  texte: 'Motif : ${motifFinal(cmd.motifPas, cmd.motifAutre)}',
                  lien: 'Modifier',
                  onLien: () => AppRoutes.nePasLivrerAvant(context),
                ),
            ],
          ),
        ),
        ChampTexte(
          key: const ValueKey('note-adv'),
          label: "Remarque pour l'ADV (facultatif)",
          valeurInitiale: cmd.note,
          onChanged: notifier.majNote,
          hint: 'Ex. prévenir le chef de rayon',
          lignes: 3,
        ),
        if (crmActif) _BlocCrm(cmd: cmd),
      ],
      bas: BarreBasse(
        blanc: true,
        enfants: [
          AppBouton(
            cmd.crm == null
                ? '⏸ Mettre en attente'
                : '⏸ Enregistrer en attente',
            variante: VarianteBouton.tonal,
            onPressed: () => mettreEnAttente(context, ref),
          ),
          AppBouton(
            '✓ Valider',
            variante: VarianteBouton.plein,
            onPressed: () => validerCommande(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Promoteur connecté : envoi de la commande par mail au client (pastille « Envoyée à … » une fois fait) et, pour une
/// commande déjà enregistrée dans le CRM, suppression.
class _BlocCrm extends ConsumerWidget {
  const _BlocCrm({required this.cmd});

  final CommandeEnCours cmd;

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final id = cmd.crm?.id;
    if (id == null) return;
    final ok = await showConfirmation(
      context,
      titre: 'Supprimer cette commande ?',
      texte: 'La commande en attente sera supprimée du CRM.',
      ok: 'Supprimer',
    );
    if (ok != true || !context.mounted) return;
    final c = ProviderScope.containerOf(context);
    final role = c.read(roleActifProvider);
    final erreur = await supprimerCommandeEnAttente(c, id);
    if (!context.mounted) return;
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
    c.read(commandeEnCoursProvider.notifier).terminer();
    c
        .read(sousOngletCommandesProvider.notifier)
        .choisir(SousOngletCommandes.attente);
    AppToast.show(context, 'Commande en attente supprimée.');
    if (role == Role.promoteur) {
      AppRoutes.allerOnglet(context, OngletApp.commandes);
    } else {
      AppRoutes.retourRacine(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envoyee = cmd.crm?.emailEnvoyeLe != null;
    return AppCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (envoyee)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                children: [
                  Pastille(
                    '✉ Envoyée à ${cmd.crm?.emailValidation ?? 'le client'}',
                    variante: VariantePastille.bleu,
                  ),
                ],
              ),
            ),
          Rangee(
            children: [
              AppBouton(
                '✉ Envoyer par mail',
                petit: true,
                variante: VarianteBouton.clair,
                onPressed: cmd.lignes.isEmpty
                    ? null
                    : () => ouvrirEnvoiMail(context),
              ),
              if (cmd.crm != null)
                AppBouton(
                  'Supprimer',
                  petit: true,
                  variante: VarianteBouton.danger,
                  onPressed: () => _supprimer(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « ＋ Ajouter des articles » de la barre du haut : bouton plein de 40 px de haut (`height:40px`).
class _BoutonAjouterArticles extends StatelessWidget {
  const _BoutonAjouterArticles({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Semantics(
      button: true,
      label: '＋ Ajouter des articles',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: u.degradeBouton,
            borderRadius: BorderRadius.circular(999),
            boxShadow: u.ombreBouton,
          ),
          // `widthFactor` : le bouton garde la largeur de son texte (`width:auto`) même sous un plafond de largeur.
          child: Center(
            widthFactor: 1,
            child: Text(
              '＋ Ajouter des articles',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.t(13, w: FontWeight.w700, c: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne du panier : produit, prix × quantité, stock, produit remplacé, compteur et alerte de stock.
class _LignePanier extends ConsumerWidget {
  const _LignePanier({required this.ligne});

  final LigneCommande ligne;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = produitParId(ligne.produitId);
    if (p == null) return const SizedBox.shrink();
    final notifier = ref.read(commandeEnCoursProvider.notifier);
    final info = infoStock(p);
    final trop = ligne.qty > (p.qte ?? 0);
    final remplace = ligne.remplace == null
        ? null
        : produitParId(ligne.remplace!);
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
                    Text.rich(
                      TextSpan(
                        text: '${euros(p.prix ?? 0)} × ${ligne.qty} = ',
                        children: [
                          TextSpan(
                            text: eurD((p.prix ?? 0) * ligne.qty),
                            style: AppText.t(12.5, w: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: AppText.sousCarte,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LigneStock(info, taille: 12),
                    ),
                    if (remplace != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Pastille(
                          '↺ Remplace ${remplace.nom}',
                          variante: VariantePastille.bleu,
                        ),
                      ),
                  ],
                ),
              ),
              StepperQte(
                valeur: ligne.qty,
                onMoins: () => notifier.retirer(p.id),
                onPlus: () => notifier.ajouter(p.id),
              ),
            ],
          ),
          if (trop)
            ErreurStock(
              texte: 'Stock insuffisant (${p.qte} disponibles).',
              lien: 'Remplacement ›',
              onLien: () => AppRoutes.produitsRemplacement(context, p.id),
            ),
        ],
      ),
    );
  }
}

/// Case « Ne pas livrer avant une date précise » (`.case-liv`) : case à cocher de 20 px d'accent `#1D4ED8`, texte gras.
class _CaseConsigne extends StatelessWidget {
  const _CaseConsigne({required this.cochee, required this.onTap});

  final bool cochee;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: cochee,
      label: 'Ne pas livrer avant une date précise',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            // Marges par défaut d'une case à cocher HTML : 3 px en haut, à droite et en bas, 4 px à gauche.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 3, 3, 3),
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cochee ? _accent : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: cochee ? _accent : const Color(0xFF767676),
                    width: 2,
                  ),
                ),
                child: cochee
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ne pas livrer avant une date précise',
                style: AppText.t(14, w: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
