import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'logic/visites_logique.dart';
import 'state/actions_visite.dart';

/// Saisie d'une étape de visite (écran empilé `saisie`). Maquette : visiteSaisie l.1282-1310.
/// Ouverte par `AppRoutes.saisieEtapeVisite(context, visiteId: ..., etape: ...)`.
///
/// Quatre saisies : vérification DN (kits), concurrence (marques et métrage), promotions et bilan de visite.
/// Toute autre étape affiche la saisie des promotions, comme la maquette.
class SaisieEtapeScreen extends ConsumerStatefulWidget {
  const SaisieEtapeScreen({
    super.key,
    required this.visiteId,
    required this.etape,
  });

  final String visiteId;
  final EtapeDph etape;

  @override
  ConsumerState<SaisieEtapeScreen> createState() => _SaisieEtapeScreenState();
}

class _SaisieEtapeScreenState extends ConsumerState<SaisieEtapeScreen> {
  final TextEditingController _marque = TextEditingController();
  final TextEditingController _metrage = TextEditingController();

  @override
  void dispose() {
    _marque.dispose();
    _metrage.dispose();
    super.dispose();
  }

  ActionsVisite get _actions =>
      ActionsVisite(ref.read(crmProvider.notifier), widget.visiteId);

  /// Contrôle puis enregistre l'étape, et revient à la liste des étapes (`v-etape-ok`).
  void _enregistrer(Visite v) {
    final erreur = erreurEnregistrement(v, widget.etape);
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
    _actions.enregistrerEtape(widget.etape);
    AppToast.show(context, messageEtapeEnregistree(widget.etape));
    Navigator.of(context).pop();
  }

  /// Ajoute la marque saisie à la liste de la concurrence (`conc-ajouter`).
  void _ajouterMarque() {
    final marque = _marque.text.trim();
    final metrage = lireDecimal(_metrage.text);
    if (marque.isEmpty) {
      AppToast.show(context, 'Indiquez la marque concurrente.');
      return;
    }
    if (metrage == null || !(metrage > 0)) {
      AppToast.show(context, 'Indiquez le métrage en mètres (ex. 1,5).');
      return;
    }
    _actions.ajouterMarque(marque, metrage);
    _marque.clear();
    _metrage.clear();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(visiteParIdProvider(widget.visiteId));
    if (v == null) {
      return PageUnivers(
        entete: TopbarEcran(titre: widget.etape.libelle, tailleTitre: 16),
        enfants: const [Vide('Visite introuvable.')],
      );
    }
    final magasin = ref.watch(magasinParIdProvider(v.magasinId));
    final corps = switch (widget.etape) {
      EtapeDph.dn => _corpsDn(context, v),
      EtapeDph.bilan => _corpsBilan(context, v, magasin),
      EtapeDph.concurrence => _corpsConcurrence(context, v),
      _ => _corpsPromos(v),
    };
    return PageUnivers(
      entete: TopbarEcran(
        titre: widget.etape.libelle,
        sous: magasin?.nom,
        tailleTitre: 16,
      ),
      enfants: corps,
      bas: BarreBasse(
        blanc: true,
        enfants: [
          AppBouton(
            '✓ Enregistrer ${objetEnregistrement(widget.etape)}',
            variante: VarianteBouton.plein,
            onPressed: () => _enregistrer(v),
          ),
        ],
      ),
    );
  }

  // ---- Vérification DN -----------------------------------------------------

  List<Widget> _corpsDn(BuildContext context, Visite v) {
    final bleu = context.univers.bleu;
    final n = v.kits.length;
    return [
      SectionTitre(
        'Distribution numérique par kit',
        couleur: bleu,
        margeHaut: 0,
      ),
      Selecteur(
        n > 0
            ? '$n kit${sPluriel(n)} sélectionné${sPluriel(n)} · ajouter ou retirer…'
            : 'Sélectionner les kits du rayon…',
        onTap: () => AppRoutes.kitsDuRayon(context, v.id),
      ),
      for (final code in v.kits)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCarte(
            child: AppLigne(
              alignement: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => AppRoutes.detailKit(context, code),
                    child: _TexteKit(kitDe(code), bleu: bleu),
                  ),
                ),
                _Retirer(onTap: () => _actions.retirerKit(code)),
              ],
            ),
          ),
        ),
      if (v.kits.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Vide(
            'Aucun kit sélectionné : choisissez les kits constatés en rayon, pour la distribution numérique.',
          ),
        ),
    ];
  }

  // ---- Concurrence -----------------------------------------------------------

  List<Widget> _corpsConcurrence(BuildContext context, Visite v) {
    final conc = v.concurrence;
    return [
      SectionTitre(
        'Marques et métrages concurrents',
        couleur: context.univers.bleu,
        margeHaut: 0,
      ),
      LigneSwitch(
        label: 'Aucune marque concurrente en rayon',
        valeur: conc.aucune,
        onChanged: (_) => _actions.basculerAucuneMarque(),
      ),
      if (!conc.aucune) ...[
        for (var i = 0; i < conc.liste.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCarte(
              child: AppLigne(
                alignement: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(conc.liste[i].marque, style: AppText.titreCarte),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${nombreFr(conc.liste[i].metrage)} m linéaire',
                            style: AppText.sousCarte,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Retirer(onTap: () => _actions.retirerMarque(i)),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCarte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChampTexte(
                  label: 'Marque concurrente',
                  controller: _marque,
                  hint: 'Ex. nom de la marque',
                ),
                ChampTexte(
                  label: 'Métrage (mètres linéaires)',
                  controller: _metrage,
                  hint: 'Ex. 1,5',
                  clavier: const TextInputType.numberWithOptions(decimal: true),
                ),
                AppBouton(
                  '＋ Ajouter cette marque',
                  petit: true,
                  variante: VarianteBouton.plein,
                  onPressed: _ajouterMarque,
                ),
              ],
            ),
          ),
        ),
        if (conc.liste.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Vide(
              'Aucune marque saisie : ajoutez les marques concurrentes et leur métrage, ou cochez « Aucune marque concurrente ».',
            ),
          ),
      ],
    ];
  }

  // ---- Promotions --------------------------------------------------------------

  List<Widget> _corpsPromos(Visite v) {
    final conformes = v.promosConformes == true;
    return [
      LigneSwitch(
        label: 'Les promotions sont en place et conformes',
        valeur: conformes,
        onChanged: (_) => _actions.definirPromos(conformes: !conformes),
      ),
      ChampTexte(
        label: 'Remarque (facultatif)',
        lignes: 3,
        hint: 'Ex. tête de gondole non refaite',
        valeurInitiale: v.promosNote,
        onChanged: _actions.noterPromos,
      ),
    ];
  }

  // ---- Bilan de visite ---------------------------------------------------------

  List<Widget> _corpsBilan(BuildContext context, Visite v, Magasin? magasin) {
    final bleu = context.univers.bleu;
    final kits = v.kits.length;
    final conc = v.concurrence;
    final sansMarque = conc.aucune || conc.liste.isEmpty;
    final metrage = conc.liste.fold<double>(0, (a, c) => a + c.metrage);
    final photos = EtapeDph.values
        .where((e) => e.estPhoto)
        .fold<int>(0, (a, e) => a + (v.photos[e] ?? 0));
    final objectif = magasin == null || magasin.reel
        ? null
        : objectifMagasin(magasin);
    String milliers(int n) => groupeMilliers(n, separateur: ' ');
    return [
      SectionTitre('Résumé des résultats', couleur: bleu, margeHaut: 0),
      LigneCle(
        'Distribution numérique',
        '$kits kit${sPluriel(kits)} vérifié${sPluriel(kits)}',
      ),
      LigneCle(
        'Concurrence',
        sansMarque
            ? 'Aucune marque'
            : '${conc.liste.length} marque${sPluriel(conc.liste.length)} · ${nombreFr(metrage)} m',
      ),
      LigneCle(
        'Promotions',
        v.promosConformes == true ? 'Conformes' : 'Non conformes',
      ),
      LigneCle('Photos', '$photos'),
      LigneCle(
        'Visite PEM',
        v.pem.realisee == true ? 'Réalisée' : 'Non réalisée',
      ),
      SectionTitre('Objectifs du magasin', couleur: bleu),
      if (objectif != null) ...[
        LigneCle(
          'CA / objectif du mois',
          '${milliers(objectif.ca)} € / ${milliers(objectif.obj)} € (${objectif.pct} %)',
        ),
        LigneCle(
          'OP en cours',
          '${objectif.ops.where((o) => o.etat == EtatOp.enCours).length}',
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: LigneSwitch(
          label: 'Je valide les objectifs et le bilan de cette visite',
          valeur: v.bilanValide,
          onChanged: (_) => _actions.basculerBilan(),
        ),
      ),
      ChampTexte(
        label: 'Commentaire (facultatif)',
        lignes: 3,
        hint: 'Ex. objectif atteint grâce à la PEM',
        valeurInitiale: v.bilanNote,
        onChanged: _actions.noterBilan,
      ),
    ];
  }
}

/// Nom d'un kit suivi d'un « › » bleu, et sa marque et sa référence dessous.
class _TexteKit extends StatelessWidget {
  const _TexteKit(this.kit, {required this.bleu});

  final Kit kit;
  final Color bleu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${kit.nom} '),
              TextSpan(
                text: '›',
                style: AppText.t(14.5, w: FontWeight.w600, c: bleu),
              ),
            ],
          ),
          style: AppText.titreCarte,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${kit.marque.isEmpty ? '' : '${kit.marque} · '}Réf. ${kit.code}',
            style: AppText.sousCarte,
          ),
        ),
      ],
    );
  }
}

/// Croix grise à droite d'une carte pour retirer l'élément.
class _Retirer extends StatelessWidget {
  const _Retirer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          '✕',
          style: AppText.t(16, w: FontWeight.w700, c: AppColors.muted),
        ),
      ),
    );
  }
}
