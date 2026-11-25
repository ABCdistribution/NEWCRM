import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/referentiels_visite.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/photos_visite_provider.dart';
import '../../core/sync/referentiels_visite_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'logic/visites_logique.dart';
import 'state/actions_visite.dart';

/// Contenu de chaque étape du parcours de visite (« Précédent » / « Suivant » sont dans l'écran de la visite).
class CorpsEtape extends ConsumerWidget {
  const CorpsEtape({super.key, required this.visite, required this.etape});

  final Visite visite;
  final EtapeDph etape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ActionsVisite(ref.read(crmProvider.notifier), visite.id);
    return switch (etape) {
      EtapeDph.arrivee ||
      EtapeDph.rayonArrivee ||
      EtapeDph.rayonFin => PhotosEtape(visite: visite, etape: etape),
      EtapeDph.colis => _EtapeColis(visite: visite, actions: actions),
      EtapeDph.dn => _EtapeDn(visite: visite, actions: actions),
      EtapeDph.indispensables => _EtapeIndispensables(
        visite: visite,
        actions: actions,
      ),
      EtapeDph.articlesPem => _EtapeArticlesPem(
        visite: visite,
        actions: actions,
      ),
      EtapeDph.commande => _EtapeCommande(visite: visite, actions: actions),
      EtapeDph.questionnaire => _EtapeQuestionnaire(
        visite: visite,
        actions: actions,
      ),
      EtapeDph.debut => const SizedBox.shrink(),
    };
  }
}

// ---- Photos ------------------------------------------------------------------

/// Photo d'une étape (une seule) : miniature, « Prendre une photo » puis « Reprendre la photo » (remplace l'ancienne,
/// appareil photo du téléphone), suppression.
class PhotosEtape extends ConsumerStatefulWidget {
  const PhotosEtape({super.key, required this.visite, required this.etape});

  final Visite visite;
  final EtapeDph etape;

  @override
  ConsumerState<PhotosEtape> createState() => _PhotosEtapeState();
}

class _PhotosEtapeState extends ConsumerState<PhotosEtape> {
  bool _occupe = false;

  ActionsVisite get _actions =>
      ActionsVisite(ref.read(crmProvider.notifier), widget.visite.id);

  Future<void> _enregistrer(List<int> octets) async {
    final ok = await ref
        .read(photosVisiteProvider(widget.visite.id).notifier)
        .remplacer(widget.etape.cle, octets);
    if (!mounted) return;
    if (!ok) {
      AppToast.show(context, 'Photo non enregistrée : base locale absente.');
      return;
    }
    _actions.ajouterPhoto(widget.etape);
  }

  Future<void> _prendre() async {
    if (_occupe) return;
    setState(() => _occupe = true);
    final photos = ref.read(photosVisiteProvider(widget.visite.id).notifier);
    // L'étape est mémorisée avant l'appareil photo : si Android ferme l'application, la photo retrouvée y sera
    // rattachée (voir `RecuperationPhoto`).
    await photos.memoriserPriseEnCours(widget.etape.cle);
    try {
      // Prise annulée ou en échec : l'ancienne photo est conservée (rien n'est touché avant d'avoir la nouvelle).
      final octets = await ref.read(captureurPhotoProvider).prendre();
      if (octets != null) await _enregistrer(octets);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, "L'appareil photo n'est pas disponible.");
      }
    } finally {
      await photos.effacerPriseEnCours();
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _supprimer() async {
    await ref
        .read(photosVisiteProvider(widget.visite.id).notifier)
        .supprimer(widget.etape.cle);
    if (mounted) _actions.retirerPhoto(widget.etape);
  }

  @override
  Widget build(BuildContext context) {
    // Une étape ne porte qu'une photo : la plus récente.
    final photo = ref
        .watch(photosVisiteProvider(widget.visite.id))
        .where((p) => p.etape == widget.etape.cle)
        .lastOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBouton(
          _occupe
              ? 'Ouverture…'
              : photo == null
              ? '📷 Prendre une photo'
              : '📷 Reprendre la photo',
          variante: VarianteBouton.plein,
          onPressed: _prendre,
        ),
        const SizedBox(height: 12),
        if (photo == null)
          const Vide('Aucune photo pour cette étape.')
        else
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Miniature(octets: photo.octets, onSupprimer: _supprimer),
            ],
          ),
      ],
    );
  }
}

class _Miniature extends StatelessWidget {
  const _Miniature({required this.octets, required this.onSupprimer});

  final List<int> octets;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            Uint8List.fromList(octets),
            fit: BoxFit.cover,
            cacheWidth: 500,
            gaplessPlayback: true,
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onSupprimer,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '✕',
                  style: AppText.t(14, w: FontWeight.w700, c: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Commande à mettre en rayon ------------------------------------------------

class _EtapeColis extends StatelessWidget {
  const _EtapeColis({required this.visite, required this.actions});

  final Visite visite;
  final ActionsVisite actions;

  @override
  Widget build(BuildContext context) {
    final oui = visite.commandeEnRayon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Y a-t-il une commande à mettre en rayon ?',
          style: AppText.t(15, w: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Segment(
          libelles: const ['Oui', 'Non'],
          index: oui == null
              ? -1
              : oui
              ? 0
              : 1,
          onChanged: (i) => actions.definirCommandeEnRayon(oui: i == 0),
        ),
      ],
    );
  }
}

// ---- Distribution numérique ----------------------------------------------------

class _EtapeDn extends StatelessWidget {
  const _EtapeDn({required this.visite, required this.actions});

  final Visite visite;
  final ActionsVisite actions;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    final v = visite;
    final n = v.kits.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitre(
          'Distribution numérique par kit',
          couleur: bleu,
          margeHaut: 0,
        ),
        Selecteur(
          n > 0
              ? '$n kit${n > 1 ? 's' : ''} sélectionné${n > 1 ? 's' : ''} · ajouter ou retirer…'
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => actions.retirerKit(code),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '✕',
                        style: AppText.t(
                          16,
                          w: FontWeight.w700,
                          c: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (v.kits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Vide(
              'Aucun kit sélectionné : choisissez les kits constatés en rayon.',
            ),
          ),
      ],
    );
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

// ---- Produits indispensables ----------------------------------------------------

/// Produits que l'enseigne exige en rayon : « Présent » ou « Absent » pour chacun.
class _EtapeIndispensables extends ConsumerWidget {
  const _EtapeIndispensables({required this.visite, required this.actions});

  final Visite visite;
  final ActionsVisite actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produits =
        ref.watch(produitsIndispensablesProvider(visite.magasinId)).value ??
        const [];
    final releves = indispensablesReleves(visite, produits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$releves/${produits.length} relevés',
                style: AppText.t(13, c: AppColors.muted),
              ),
            ),
            AppBouton(
              'Tout présent',
              variante: VarianteBouton.clair,
              petit: true,
              pleineLargeur: false,
              onPressed: () =>
                  actions.toutPresent([for (final p in produits) p.articleId]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final p in produits)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCarte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.libelle, style: AppText.titreCarte),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 10),
                    child: Text(
                      '${p.marque.isEmpty ? '' : '${p.marque} · '}Réf. ${p.code}',
                      style: AppText.sousCarte,
                    ),
                  ),
                  Segment(
                    libelles: const ['Présent', 'Absent'],
                    index: switch (visite.indispensables[p.articleId]) {
                      true => 0,
                      false => 1,
                      null => -1,
                    },
                    margeBas: 0,
                    onChanged: (i) => actions.releverIndispensable(
                      p.articleId,
                      present: i == 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Articles PEM ---------------------------------------------------------------------------------

/// Articles PEM du CRM : « Présent » ou « Absent » pour chacun, puis « Mis en avant » pour ceux qui sont présents.
/// Rien n'est présélectionné.
class _EtapeArticlesPem extends ConsumerWidget {
  const _EtapeArticlesPem({required this.visite, required this.actions});

  final Visite visite;
  final ActionsVisite actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(articlesPemProvider).value ?? const [];
    final releves = articlesPemReleves(visite, articles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$releves/${articles.length} relevés',
          style: AppText.t(13, c: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final a in articles)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCarte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.libelle, style: AppText.titreCarte),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 10),
                    child: Text(
                      [
                        if (a.marque.isNotEmpty) a.marque,
                        if (a.code.isNotEmpty) a.code,
                      ].join(' · '),
                      style: AppText.sousCarte,
                    ),
                  ),
                  Segment(
                    libelles: const ['Présent', 'Absent'],
                    index: switch (visite.articlesPem[a.articleId]?.present) {
                      true => 0,
                      false => 1,
                      null => -1,
                    },
                    margeBas: 0,
                    onChanged: (i) =>
                        actions.releverArticlePem(a.articleId, present: i == 0),
                  ),
                  if (visite.articlesPem[a.articleId]?.present == true)
                    LigneSwitch(
                      label: 'Mis en avant',
                      valeur: visite.articlesPem[a.articleId]!.misEnAvant,
                      onChanged: (v) => actions.mettreEnAvantArticlePem(
                        a.articleId,
                        misEnAvant: v,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Commande liée / raison d'absence -------------------------------------------

class _EtapeCommande extends ConsumerStatefulWidget {
  const _EtapeCommande({required this.visite, required this.actions});

  final Visite visite;
  final ActionsVisite actions;

  @override
  ConsumerState<_EtapeCommande> createState() => _EtapeCommandeState();
}

class _EtapeCommandeState extends ConsumerState<_EtapeCommande> {
  /// Réponse à « une commande liée à cette visite ? » : nulle tant qu'on n'a pas répondu.
  late bool? _oui = widget.visite.cmd != null
      ? true
      : widget.visite.raisonAbsence.isNotEmpty
      ? false
      : null;

  @override
  Widget build(BuildContext context) {
    final v = widget.visite;
    final raisons = ref.watch(raisonsAbsenceProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Une commande est-elle liée à cette visite ?',
          style: AppText.t(15, w: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Segment(
          libelles: const ['Oui', 'Non'],
          index: _oui == null
              ? -1
              : _oui!
              ? 0
              : 1,
          onChanged: (i) {
            setState(() => _oui = i == 0);
            if (i == 0) widget.actions.effacerRaisonAbsence();
          },
        ),
        if (_oui == true) ...[
          AppCarte(
            child: v.cmd == null
                ? Text(
                    'Aucune commande prise pour le moment.',
                    style: AppText.t(15, c: AppColors.muted),
                  )
                : Text(
                    'Commande #${v.cmd!.id} : ${v.cmd!.ht} - ${v.cmd!.liv}',
                    style: AppText.gras,
                  ),
          ),
          const SizedBox(height: 12),
          AppBouton(
            v.cmd == null
                ? '🛒 Prendre la commande'
                : '🛒 Modifier la commande',
            variante: VarianteBouton.plein,
            onPressed: () => AppRoutes.priseCommande(
              context,
              magasinId: v.magasinId,
              visiteId: v.id,
            ),
          ),
        ],
        if (_oui == false) ...[
          Text(
            "Raison de l'absence de commande :",
            style: AppText.t(13, c: AppColors.muted),
          ),
          const SizedBox(height: 8),
          if (raisons.isEmpty)
            const Vide("Aucune raison n'est définie dans le CRM.")
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in raisons)
                  _Puce(
                    r.libelle,
                    selectionne: v.raisonAbsenceId == r.id,
                    onTap: () =>
                        widget.actions.choisirRaisonAbsence(r.id, r.libelle),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

/// Puce blanche, ou pleine couleur quand elle est choisie.
class _Puce extends StatelessWidget {
  const _Puce(this.label, {required this.selectionne, required this.onTap});

  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? bleu : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selectionne ? bleu : AppColors.bordureChamp,
          ),
        ),
        child: Text(
          label,
          style: AppText.t(
            13.5,
            c: selectionne ? Colors.white : AppColors.texte,
          ),
        ),
      ),
    );
  }
}

// ---- Questionnaire de fin de visite ---------------------------------------------

class _EtapeQuestionnaire extends ConsumerWidget {
  const _EtapeQuestionnaire({required this.visite, required this.actions});

  final Visite visite;
  final ActionsVisite actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionnaireProvider).value ?? const [];
    if (questions.isEmpty) {
      return const Vide("Aucune question n'est définie dans le CRM.");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final q in questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCarte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.obligatoire ? '${q.libelle} *' : q.libelle,
                    style: AppText.titreCarte,
                  ),
                  const SizedBox(height: 10),
                  _ReponseQuestion(
                    question: q,
                    valeur: visite.reponses[q.id] ?? '',
                    onChanged: (val) => actions.repondre(q.id, val),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReponseQuestion extends StatelessWidget {
  const _ReponseQuestion({
    required this.question,
    required this.valeur,
    required this.onChanged,
  });

  final QuestionFin question;
  final String valeur;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case TypeQuestionFin.caseACocher:
        return Segment(
          libelles: const ['Oui', 'Non'],
          index: valeur == 'true'
              ? 0
              : valeur == 'false'
              ? 1
              : -1,
          margeBas: 0,
          onChanged: (i) => onChanged(i == 0 ? 'true' : 'false'),
        );
      case TypeQuestionFin.note:
        return Segment(
          libelles: const ['1', '2', '3', '4', '5'],
          index: (int.tryParse(valeur) ?? 0) - 1,
          margeBas: 0,
          onChanged: (i) => onChanged('${i + 1}'),
        );
      case TypeQuestionFin.nombre:
        return ChampTexte(
          label: 'Réponse',
          valeurInitiale: valeur,
          clavier: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
        );
      case TypeQuestionFin.texte:
        return ChampTexte(
          label: 'Réponse',
          lignes: 3,
          valeurInitiale: valeur,
          onChanged: onChanged,
        );
    }
  }
}
