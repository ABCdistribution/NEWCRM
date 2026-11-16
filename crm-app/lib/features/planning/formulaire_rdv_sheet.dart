import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/logique_planning.dart';
import 'state/planning_state.dart';
import 'widgets/case_navigateur.dart';
import 'widgets/champ_heure.dart';

/// Ouvre la feuille de saisie d'une ligne de planning. Maquette : `formulaire` l.1938-1957 et
/// `formulairePromoteur` l.1926-1937. Appelée par `AppRoutes.formulaireRdv(...)`.
///
/// Une semaine validée est verrouillée : un message remplace la feuille (`verrou`).
Future<void> ouvrirFormulaireRdv(
  BuildContext context, {
  CiblePlanning? cible,
  String? ref,
  bool depuisFiche = false,
  bool visite = true,
  String? etapeId,
  String? planCible,
  int? semaine,
}) {
  if (ProviderScope.containerOf(context).read(planningProvider).verrouillee) {
    AppToast.show(context, "Rapport validé : plus rien n'est modifiable.");
    return Future<void>.value();
  }
  return showAppSheet<void>(
    context,
    builder: (_) => FormulaireRdvSheet(
      cible: cible,
      refCible: ref,
      depuisFiche: depuisFiche,
      visite: visite,
      etapeId: etapeId,
      planCible: planCible,
      semaine: semaine,
    ),
  );
}

/// Feuille « Nouveau RDV » / « Modifier la ligne » / « Planifier une visite client ».
///
/// - Sur son propre planning (`planCible` nul) : Client, Prospect, Libre ou ADM, jour, heure, type de visite, soirée
///   étape (lieu et adresse obligatoires), observations. Depuis une fiche (`depuisFiche`) la cible est déjà choisie.
/// - Sur le planning d'un promoteur (`planCible` = son nom) : uniquement une visite chez un client, avec une consigne.
///
/// L'enregistrement ajoute ou modifie la ligne dans le store (`ajouterEtape`, `majEtape`, `supprimerEtape`).
class FormulaireRdvSheet extends ConsumerStatefulWidget {
  const FormulaireRdvSheet({
    super.key,
    this.cible,
    this.refCible,
    this.depuisFiche = false,
    this.visite = true,
    this.etapeId,
    this.planCible,
    this.semaine,
  });

  /// Nature de la ligne proposée au départ (client par défaut).
  final CiblePlanning? cible;

  /// Client ou prospect proposé au départ.
  final String? refCible;

  /// Ouverte depuis une fiche client ou prospect : le choix de la cible, l'adresse et la soirée étape sont masqués.
  final bool depuisFiche;

  /// Indicateur « visite simple » proposé au départ d'une nouvelle ligne (`f.visite` de la maquette, vrai par défaut).
  /// À l'enregistrement, le type de visite choisi le remplace, sauf pour une ligne administrative.
  final bool visite;

  /// Ligne à modifier ; nul = nouvelle ligne.
  final String? etapeId;

  /// Nom du promoteur dont l'encadrement compose le planning ; nul = son propre planning.
  final String? planCible;

  /// Décalage de la semaine affichée du promoteur (0 = semaine 45).
  final int? semaine;

  @override
  ConsumerState<FormulaireRdvSheet> createState() => _FormulaireRdvSheetState();
}

class _FormulaireRdvSheetState extends ConsumerState<FormulaireRdvSheet> {
  static const _ordreCibles = [
    CiblePlanning.client,
    CiblePlanning.prospect,
    CiblePlanning.libre,
    CiblePlanning.adm,
  ];
  static const _types = {
    'visite': 'Visite simple',
    'acc': 'Accompagnement',
    'rdv': 'RDV',
    'appel': 'Appel téléphonique',
    'remp': 'Visite de remplacement',
  };

  final _libelle = TextEditingController();
  final _adresse = TextEditingController();
  final _note = TextEditingController();
  final _lieu = TextEditingController();
  final _adr = TextEditingController();
  final _defilement = ScrollController();

  EtapePlanning? _edition;
  late CiblePlanning _cible;
  String? _ref;
  late int _jour;
  String _heure = '';
  bool _visite = true;
  bool _acc = false;
  bool _rdv = false;
  bool _appel = false;
  bool _remp = false;
  bool _soiree = false;
  bool _fait = false;
  String? _erreur;

  bool get _pourPromoteur => widget.planCible != null;

  /// Type de visite affiché dans la liste, déduit des indicateurs de la ligne.
  String get _type => _remp
      ? 'remp'
      : _appel
      ? 'appel'
      : _acc
      ? 'acc'
      : _rdv
      ? 'rdv'
      : 'visite';

  @override
  void initState() {
    super.initState();
    final etat = ref.read(crmProvider);
    final plan = widget.planCible;
    final lignes = plan == null ? etat.etapes : etat.planDe(plan);
    _edition = widget.etapeId == null
        ? null
        : lignes.where((e) => e.id == widget.etapeId).firstOrNull;
    final e = _edition;
    if (e != null) {
      _cible = e.cible;
      _ref = e.ref;
      _jour = e.jour;
      _heure = e.heure;
      _visite = e.visite;
      _acc = e.acc;
      _rdv = e.rdv;
      _appel = e.appel;
      _remp = e.remp;
      _soiree = e.soiree;
      _fait = e.fait;
      _libelle.text = e.cible == CiblePlanning.libre ? e.titre : '';
      _note.text = e.note;
      _lieu.text = e.soireeLieu ?? '';
      _adr.text = e.soireeAdr ?? '';
    } else {
      _cible = widget.cible ?? CiblePlanning.client;
      _ref = widget.refCible ?? _premier(_cible, etat);
      _jour = ref.read(jourPlanningProvider);
      _visite = widget.visite;
    }
  }

  @override
  void dispose() {
    _libelle.dispose();
    _adresse.dispose();
    _note.dispose();
    _lieu.dispose();
    _adr.dispose();
    _defilement.dispose();
    super.dispose();
  }

  /// Premier client ou premier prospect de la liste visible du profil.
  String? _premier(CiblePlanning cible, CrmEtat etat) =>
      cible == CiblePlanning.client
      ? etat.magasins.firstOrNull?.id
      : etat.prospects.firstOrNull?.id;

  void _changerCible(CiblePlanning cible) {
    setState(() {
      _cible = cible;
      _ref = _premier(cible, ref.read(crmProvider));
    });
  }

  void _changerType(String type) {
    setState(() {
      _visite = type == 'visite';
      _acc = type == 'acc';
      _rdv = type == 'rdv';
      _appel = type == 'appel';
      _remp = type == 'remp';
    });
  }

  void _montrerErreur(String message) {
    setState(() => _erreur = message);
    if (_defilement.hasClients) _defilement.jumpTo(0);
  }

  /// Identifiant d'une nouvelle ligne : « e » et cinq caractères au hasard, jamais déjà pris.
  String _nouvelId(Iterable<EtapePlanning> existantes) {
    final pris = existantes.map((e) => e.id).toSet();
    final hasard = Random();
    while (true) {
      final id =
          'e${hasard.nextInt(36 * 36 * 36 * 36 * 36).toRadixString(36).padLeft(5, '0')}';
      if (!pris.contains(id)) return id;
    }
  }

  /// `f-ok` : contrôle la saisie puis ajoute ou met à jour la ligne.
  void _enregistrer() {
    final etat = ref.read(crmProvider);
    final plan = widget.planCible;
    var cible = _cible;
    var visite = _visite;
    var rdv = _rdv;
    var appel = _appel;
    var remp = _remp;
    var soiree = _soiree;
    if (_pourPromoteur) {
      // Planning d'un promoteur : uniquement des visites chez un client.
      cible = CiblePlanning.client;
      visite = true;
      rdv = false;
      appel = false;
      remp = false;
      soiree = false;
    } else if (cible != CiblePlanning.adm) {
      visite = _type == 'visite';
      rdv = _type == 'rdv';
      appel = _type == 'appel';
      remp = _type == 'remp';
      soiree = widget.depuisFiche ? false : _soiree;
    }
    final acc = !_pourPromoteur && cible != CiblePlanning.adm
        ? _type == 'acc'
        : _acc;
    if (cible == CiblePlanning.libre && _libelle.text.trim().isEmpty) {
      return _montrerErreur('Indiquez le client ou le lieu.');
    }
    var lieu = _lieu.text;
    var adresse = _adr.text;
    if (soiree && cible != CiblePlanning.adm) {
      if (lieu.trim().isEmpty || adresse.trim().isEmpty) {
        return _montrerErreur(
          "Soirée étape : le lieu et l'adresse sont obligatoires.",
        );
      }
    } else {
      lieu = '';
      adresse = '';
    }
    final String? titre = switch (cible) {
      CiblePlanning.adm => 'Administratif',
      CiblePlanning.libre => _libelle.text.trim(),
      CiblePlanning.client => etat.magasinParId(_ref ?? '')?.nom,
      CiblePlanning.prospect => etat.prospectParId(_ref ?? '')?.nom,
    };
    if (titre == null) return _montrerErreur('Indiquez le client ou le lieu.');

    final lignes = plan == null ? etat.etapes : etat.planDe(plan);
    final edition = _edition;
    final ligne = EtapePlanning(
      id: edition?.id ?? _nouvelId(lignes),
      jour: _jour,
      heure: _heure,
      cible: cible,
      ref: cible == CiblePlanning.client || cible == CiblePlanning.prospect
          ? _ref
          : null,
      titre: titre,
      visite: visite,
      acc: acc,
      rdv: rdv,
      appel: appel,
      remp: remp,
      soiree: soiree,
      soireeLieu: lieu,
      soireeAdr: adresse,
      note: _note.text,
      fait: _fait,
      sem: plan != null ? (widget.semaine ?? 0) : null,
    );
    final store = ref.read(crmProvider.notifier);
    if (edition != null) {
      store.majEtape(edition.id, (_) => ligne, pour: plan);
    } else {
      store.ajouterEtape(ligne, pour: plan);
    }
    ref.read(jourPlanningProvider.notifier).choisir(_jour);
    AppToast.show(
      context,
      edition != null ? 'Ligne enregistrée.' : 'Ligne ajoutée au planning.',
    );
    if (plan == null) {
      // Sur son propre planning : retour à l'onglet Planning, sur le jour de la ligne.
      AppRoutes.allerOnglet(context, OngletApp.planning);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// `f-suppr` : retire la ligne en cours de modification.
  void _supprimer() {
    final edition = _edition;
    if (edition == null) return;
    ref
        .read(crmProvider.notifier)
        .supprimerEtape(edition.id, pour: widget.planCible);
    AppToast.show(context, 'Ligne supprimée.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(crmProvider);
    final edition = _edition != null;
    final plan = widget.planCible;
    final String titre;
    final List<Widget> champs;
    if (plan != null) {
      titre =
          '${edition ? 'Modifier la visite' : 'Planifier une visite client'} · $plan';
      champs = _champsPromoteur(etat, plan);
    } else {
      final nom = widget.depuisFiche
          ? (_cible == CiblePlanning.client
                    ? etat.magasinParId(_ref ?? '')?.nom
                    : etat.prospectParId(_ref ?? '')?.nom) ??
                ''
          : '';
      titre = widget.depuisFiche
          ? 'Planifier · $nom'
          : edition
          ? 'Modifier la ligne'
          : 'Nouveau RDV';
      champs = _champs(etat);
    }
    return _FeuilleHaute(
      titre: titre,
      controleur: _defilement,
      children: [
        if (_erreur != null) MessageErreur(_erreur!),
        ...champs,
        Rangee(
          children: [
            AppBouton(
              'Annuler',
              petit: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppBouton(
              edition
                  ? 'Enregistrer'
                  : plan != null
                  ? 'Ajouter la visite'
                  : 'Ajouter la ligne',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: _enregistrer,
            ),
          ],
        ),
        if (edition)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppBouton(
              plan != null ? 'Supprimer la visite' : 'Supprimer la ligne',
              petit: true,
              variante: VarianteBouton.danger,
              onPressed: _supprimer,
            ),
          ),
      ],
    );
  }

  /// Champs du formulaire de son propre planning (`formulaire`).
  List<Widget> _champs(CrmEtat etat) {
    final cible = _cible;
    final depuisFiche = widget.depuisFiche;
    final clientOuProspect =
        cible == CiblePlanning.client || cible == CiblePlanning.prospect;
    final choix = cible == CiblePlanning.client
        ? {for (final m in etat.magasins) m.id: m.nom}
        : {for (final p in etat.prospects) p.id: p.nom};
    return [
      if (!depuisFiche)
        Segment(
          libelles: [for (final c in _ordreCibles) c.libelle],
          index: _ordreCibles.indexOf(cible),
          onChanged: (i) => _changerCible(_ordreCibles[i]),
        ),
      if (!depuisFiche && clientOuProspect)
        ChampListe<String>(
          key: ValueKey('ref-${cible.code}'),
          label: cible == CiblePlanning.client ? 'Client' : 'Prospect',
          valeur: _ref ?? '',
          options: choix,
          onChanged: (v) => setState(() => _ref = v),
        ),
      if (cible == CiblePlanning.libre)
        ChampTexte(
          label: 'Client ou lieu',
          controller: _libelle,
          hint: 'ex. Chez Marcel',
        ),
      if (cible != CiblePlanning.adm && !depuisFiche)
        ChampTexte(label: 'Adresse (facultatif)', controller: _adresse),
      _jourEtHeure([
        for (var i = 0; i < 5; i++)
          '${joursCourts[i]} ${semaineInfo(0).dates[i]} ${semaineInfo(0).mois[i]}',
      ]),
      if (cible != CiblePlanning.adm) ...[
        ChampListe<String>(
          label: 'Type de visite',
          valeur: _type,
          options: _types,
          onChanged: _changerType,
        ),
        if (!depuisFiche)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CaseNavigateur(
              label: 'Soirée étape',
              cochee: _soiree,
              onChanged: (v) => setState(() => _soiree = v),
            ),
          ),
      ],
      if (_soiree && !depuisFiche && cible != CiblePlanning.adm) ...[
        ChampTexte(
          label: 'Lieu de la soirée étape (obligatoire)',
          controller: _lieu,
        ),
        ChampTexte(
          label: 'Adresse de la soirée étape (obligatoire)',
          controller: _adr,
        ),
      ],
      ChampTexte(label: 'Observations', controller: _note, lignes: 3),
      if (_edition != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CaseNavigateur(
            label: 'Visite effectuée',
            cochee: _fait,
            onChanged: (v) => setState(() => _fait = v),
          ),
        ),
    ];
  }

  /// Champs du formulaire du planning d'un promoteur (`formulairePromoteur`) : client de ses visites, jour, heure,
  /// consigne.
  List<Widget> _champsPromoteur(CrmEtat etat, String plan) {
    final clients = clientsDe(plan, etat.magasins);
    if (!clients.any((c) => c.id == _ref) && clients.isNotEmpty) {
      _ref = clients.first.id;
    }
    final semaine = semaineInfo(widget.semaine ?? 0);
    return [
      ChampListe<String>(
        label: 'Client',
        valeur: _ref ?? '',
        options: {for (final c in clients) c.id: c.nom},
        onChanged: (v) => setState(() => _ref = v),
      ),
      _jourEtHeure([
        for (var i = 0; i < 5; i++)
          '${joursCourts[i]} ${semaine.dates[i]} ${semaine.mois[i]}',
      ]),
      ChampTexte(
        label: 'Consigne pour le promoteur (facultatif)',
        controller: _note,
        lignes: 3,
      ),
    ];
  }

  /// Rangée « Jour » et « Heure » ; `libellesJours` : un texte par jour de la semaine.
  Widget _jourEtHeure(List<String> libellesJours) {
    return Rangee(
      children: [
        ChampListe<int>(
          label: 'Jour',
          valeur: _jour,
          options: {
            for (var i = 0; i < libellesJours.length; i++) i: libellesJours[i],
          },
          onChanged: (v) => setState(() => _jour = v),
        ),
        ChampHeure(
          valeur: _heure,
          onChanged: (v) => setState(() => _heure = v),
        ),
      ],
    );
  }
}

/// Feuille basse du formulaire (`.feuille` avec `max-height: 94 %`) : comme `FeuilleBase`, un peu plus haute, avec un
/// défilement que la feuille remonte en haut pour montrer un message d'erreur.
class _FeuilleHaute extends StatelessWidget {
  const _FeuilleHaute({
    required this.titre,
    required this.controleur,
    required this.children,
  });

  final String titre;
  final ScrollController controleur;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.94),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: controleur,
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            20 + mq.viewInsets.bottom + mq.padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(titre, style: AppText.titreFeuille),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
