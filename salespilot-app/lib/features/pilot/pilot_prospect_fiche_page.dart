import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/role.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../prechargement.dart';
import 'pilot_prospects_page.dart' show prochaineAction;
import 'prospects_pipeline.dart';
import 'tournee_etapes.dart';

const _moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _joursCourts = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// Libellés des étapes du serveur (`PipelineEtape`), tels qu'on les montre dans la timeline.
const _libellesStatut = {
  'NOUVEAU': 'Fiche créée',
  'CONTACTE': 'Contacté',
  'VISITE': 'RDV pris',
  'PROPOSITION': 'Proposition',
  'NEGOCIATION': 'En négociation',
  'GAGNE': 'Référencé',
  'PERDU': 'Perdu',
};

const _motifsPerte = {
  'PRIX': 'Prix',
  'CONCURRENCE': 'Concurrence',
  'PAS_DE_BESOIN': 'Pas de besoin',
  'SANS_REPONSE': 'Sans réponse',
  'AUTRE': 'Autre',
};

/// Un événement de la timeline : titre, détail et date, avec son icône.
class EvenementProspect {
  const EvenementProspect({required this.icone, required this.couleur, required this.titre, required this.date, this.detail});

  final IconData icone;
  final Color couleur;
  final String titre;
  final String? detail;
  final DateTime date;
}

String? _t(Object? v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// Fiche prospect (maquette) : coordonnées, étape de prospection, contact principal et timeline.
class FicheProspect {
  const FicheProspect({
    required this.id,
    required this.enseigne,
    required this.statut,
    required this.probabilite,
    required this.evenements,
    this.raisonSociale,
    this.adresse,
    this.codePostal,
    this.ville,
    this.telephone,
    this.latitude,
    this.longitude,
    this.potentiel,
    this.niveauClass,
    this.source,
    this.auteur,
    this.creeLe,
    this.contact,
    this.contactTelephone,
  });

  final String id;
  final String enseigne;
  final String? raisonSociale;
  final String? adresse;
  final String? codePostal;
  final String? ville;
  final String? telephone;
  final double? latitude;
  final double? longitude;
  final String statut;
  final int probabilite;
  final double? potentiel;
  final String? niveauClass;
  final String? source;
  final String? auteur;
  final DateTime? creeLe;
  final String? contact;
  final String? contactTelephone;
  final List<EvenementProspect> evenements;

  GroupeProspect? get groupe => GroupeProspect.de(statut);

  /// Nombre de segments remplis de la barre d'étape (fiche créée, à contacter, RDV pris, en négo, référencé).
  int get segments => switch (statut) {
        'NOUVEAU' => 1,
        'CONTACTE' => 2,
        'VISITE' => 3,
        'PROPOSITION' || 'NEGOCIATION' => 4,
        'GAGNE' => 5,
        _ => 1,
      };

  String get adresseComplete =>
      [?adresse, [?codePostal, ?ville].join(' ')].where((s) => s.trim().isNotEmpty).join(', ');

  bool get aUneAdresse => (latitude != null && longitude != null) || adresseComplete.isNotEmpty;

  /// Lit `GET /prospects/:id` et `GET /prospects/:id/historique`.
  factory FicheProspect.fromJson(Map<String, dynamic> fiche, Map<String, dynamic> historique) {
    final contacts = ((fiche['contacts'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final c = contacts.isEmpty ? null : contacts.last; // le premier saisi : la liste arrive du plus récent au plus ancien
    final nomContact = c == null ? null : [_t(c['prenom']), _t(c['nom'])].whereType<String>().join(' ');
    final poste = c == null ? null : (_t(c['poste']) ?? _t(c['typePoste']));
    final enseigne = _t(fiche['enseigne']) ?? _t(fiche['raisonSociale']) ?? 'Sans nom';
    final createdBy = fiche['createdBy'] as Map<String, dynamic>?;
    final evenements = <EvenementProspect>[
      for (final e in ((historique['data'] as List?) ?? const []).cast<Map<String, dynamic>>()) ?_evenement(e),
    ];
    final creeLe = DateTime.tryParse('${fiche['createdAt']}')?.toLocal();
    final source = switch (fiche['source']) { 'SALON' => 'salon', 'RECOMMANDATION' => 'recommandation', 'TERRAIN' => 'terrain', 'WEB' => 'web', _ => null };
    final auteurFiche = _t(createdBy?['displayName']);
    if (creeLe != null) {
      evenements.add(EvenementProspect(
        icone: Icons.add,
        couleur: const Color(0xFF6B7280),
        titre: 'Fiche créée',
        detail: [if (source != null) 'Source : $source', if (auteurFiche != null) 'par $auteurFiche'].join(' · ').isEmpty
            ? null
            : [if (source != null) 'Source : $source', if (auteurFiche != null) 'par $auteurFiche'].join(' · '),
        date: creeLe,
      ));
    }
    return FicheProspect(
      id: fiche['id'] as String,
      enseigne: enseigne,
      raisonSociale: _t(fiche['raisonSociale']),
      adresse: _t(fiche['adresse1']),
      codePostal: _t(fiche['codePostal']),
      ville: _t(fiche['ville']),
      telephone: _t(fiche['telephone']),
      latitude: (fiche['latitude'] as num?)?.toDouble(),
      longitude: (fiche['longitude'] as num?)?.toDouble(),
      statut: fiche['statut'] as String? ?? 'NOUVEAU',
      probabilite: (fiche['probabilite'] as num?)?.toInt() ?? 0,
      potentiel: fiche['potentielCaAnnuel'] == null ? null : double.tryParse('${fiche['potentielCaAnnuel']}'),
      niveauClass: _t(fiche['niveauClass']),
      source: _t(fiche['source']),
      auteur: _t(createdBy?['displayName']),
      creeLe: creeLe,
      contact: nomContact == null || nomContact.isEmpty ? null : (poste == null ? nomContact : '$nomContact, $poste'),
      contactTelephone: c == null ? null : (_t(c['portable']) ?? _t(c['fixe'])),
      evenements: evenements,
    );
  }

  static EvenementProspect? _evenement(Map<String, dynamic> e) {
    final date = DateTime.tryParse('${e['date']}')?.toLocal();
    if (date == null) return null;
    switch (e['type']) {
      case 'VISITE':
        final v = (e['visite'] as Map<String, dynamic>?) ?? const {};
        final qui = _t((v['promoteur'] as Map?)?['displayName']);
        return EvenementProspect(
          icone: Icons.place_outlined,
          couleur: const Color(0xFF16A34A),
          titre: 'Visite${_t(v['motif']) == null ? '' : ' · ${_t(v['motif'])}'}',
          detail: _t(v['pmcCommentaire']) ?? qui,
          date: date,
        );
      case 'OPPORTUNITE':
        final o = (e['opportunite'] as Map<String, dynamic>?) ?? const {};
        final type = switch (o['type']) { 'REFERENCEMENT' => 'Référencement', 'OP' => 'Opération promo', 'MISE_EN_AVANT' => 'Mise en avant', _ => 'Opportunité' };
        return EvenementProspect(
          icone: Icons.local_offer_outlined,
          couleur: const Color(0xFFD97706),
          titre: 'Opportunité · $type',
          detail: _t(o['libelle']),
          date: date,
        );
      case 'APPEL':
        final a = (e['appel'] as Map<String, dynamic>?) ?? const {};
        final resultat = switch (a['resultat']) {
          'REPONDU' => 'Répondu',
          'SANS_REPONSE' => 'Sans réponse',
          'MESSAGERIE' => 'Messagerie',
          'RAPPEL_PREVU' => 'Rappel prévu',
          _ => null,
        };
        return EvenementProspect(
          icone: Icons.phone_outlined,
          couleur: const Color(0xFF2563EB),
          titre: 'Appel${resultat == null ? '' : ' · $resultat'}',
          detail: _t(a['commentaire']),
          date: date,
        );
      case 'EMAIL':
        final m = (e['email'] as Map<String, dynamic>?) ?? const {};
        return EvenementProspect(
          icone: Icons.mail_outline,
          couleur: const Color(0xFF2563EB),
          titre: 'E-mail${_t(m['sujet']) == null ? '' : ' · ${_t(m['sujet'])}'}',
          detail: _t(m['commentaire']) ?? _t(m['destinataire']),
          date: date,
        );
      case 'ETAPE':
        final s = (e['etape'] as Map<String, dynamic>?) ?? const {};
        final vers = _libellesStatut[s['vers']] ?? '${s['vers']}';
        final de = _libellesStatut[s['de']];
        return EvenementProspect(
          icone: Icons.description_outlined,
          couleur: const Color(0xFFD97706),
          titre: 'Étape → $vers',
          detail: _t(s['commentaire']) ?? (de == null ? null : 'Passé de « $de » à « $vers »'),
          date: date,
        );
      case 'NOTE':
        final n = (e['note'] as Map<String, dynamic>?) ?? const {};
        return EvenementProspect(
          icone: Icons.edit_outlined,
          couleur: const Color(0xFF6B7280),
          titre: 'Note',
          detail: _t(n['remarque']),
          date: date,
        );
    }
    return null;
  }
}

/// Fiche et timeline : le réseau d'abord (elles changent à chaque action), la copie locale en secours hors ligne.
final ficheProspectProvider = FutureProvider.autoDispose.family<FicheProspect, String>((ref, id) async {
  final userId = ref.watch(currentUserIdProvider);
  final cache = userId == null ? null : ref.read(cacheRepositoryProvider);
  final cle = 'prospect-fiche-$id';
  try {
    final dio = ref.read(dioProvider);
    final res = await Future.wait([
      dio.get<Map<String, dynamic>>('/prospects/$id'),
      dio.get<Map<String, dynamic>>('/prospects/$id/historique'),
    ]);
    final brut = {'fiche': res[0].data ?? const {}, 'historique': res[1].data ?? const {}};
    if (cache != null) await cache.put(userId!, cle, brut);
    return FicheProspect.fromJson(brut['fiche']!, brut['historique']!);
  } on Object {
    final copie = cache == null ? null : await cache.get(userId!, cle);
    if (copie != null) {
      final m = Map<String, dynamic>.from(copie.value as Map);
      return FicheProspect.fromJson(Map<String, dynamic>.from(m['fiche'] as Map), Map<String, dynamic>.from(m['historique'] as Map));
    }
    rethrow;
  }
});

String _dateCourte(DateTime d) => '${d.day} ${_moisCourts[d.month - 1]}';

class PilotProspectFichePage extends ConsumerStatefulWidget {
  const PilotProspectFichePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PilotProspectFichePage> createState() => _PilotProspectFichePageState();
}

class _PilotProspectFichePageState extends ConsumerState<PilotProspectFichePage> {
  bool _occupe = false;

  void _message(String texte) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _ouvrir(Uri uri, String echec) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) _message(echec);
    } on Object {
      if (mounted) _message(echec);
    }
  }

  void _appeler(FicheProspect p) {
    final tel = p.telephone ?? p.contactTelephone;
    if (tel == null) return _message('Aucun numéro de téléphone renseigné.');
    _ouvrir(Uri(scheme: 'tel', path: tel.replaceAll(' ', '')), 'Impossible de lancer l\'appel.');
  }

  void _itineraire(FicheProspect p) {
    if (!p.aUneAdresse) return _message('Aucune adresse renseignée pour ce prospect.');
    final nom = Uri.encodeComponent(p.enseigne);
    final uri = p.latitude != null && p.longitude != null
        ? Uri.parse('geo:${p.latitude},${p.longitude}?q=${p.latitude},${p.longitude}($nom)')
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(p.adresseComplete)}');
    _ouvrir(uri, 'Aucune application de cartes disponible.');
  }

  void _planifier(FicheProspect p) {
    final q = {'prospectId': p.id, 'nom': p.enseigne, if (p.ville != null) 'ville': p.ville!};
    context.push(Uri(path: '/rdv/nouveau', queryParameters: q).toString());
  }

  /// Action serveur (en ligne) : actualise la fiche puis confirme, ou affiche le motif du refus.
  Future<void> _executer(Future<void> Function() action, String succes) async {
    setState(() => _occupe = true);
    try {
      await action();
      ref.invalidate(ficheProspectProvider(widget.id));
      ref.invalidate(prospectsPipelineProvider);
      await ref.read(miseAJourLocaleProvider).prospection();
      if (mounted) _message(succes);
    } on Object catch (e) {
      if (mounted) _message(errorMessage(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _note() async {
    final champ = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ajouter une note'),
        content: TextField(controller: champ, autofocus: true, minLines: 3, maxLines: 6, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, champ.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    champ.dispose();
    if (texte == null || texte.isEmpty || !mounted) return;
    await _executer(() => ref.read(dioProvider).post('/prospects/${widget.id}/notes', data: {'remarque': texte}), 'Note ajoutée.');
  }

  Future<void> _changerEtape(FicheProspect p) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Changer d\'étape', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
          for (final s in ['NOUVEAU', 'CONTACTE', 'VISITE', 'PROPOSITION', 'NEGOCIATION', 'PERDU'])
            ListTile(
              title: Text(_libellesStatut[s]!),
              trailing: s == p.statut ? Icon(Icons.check, color: SpacePalette.pilot.accent) : null,
              onTap: s == p.statut ? null : () => Navigator.pop(c, s),
            ),
        ]),
      ),
    );
    if (choix == null || !mounted) return;
    String? motif;
    if (choix == 'PERDU') {
      motif = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Motif de la perte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
            for (final m in _motifsPerte.entries) ListTile(title: Text(m.value), onTap: () => Navigator.pop(c, m.key)),
          ]),
        ),
      );
      if (motif == null || !mounted) return;
    }
    await _executer(
      () => ref.read(dioProvider).patch('/prospects/${widget.id}', data: {'statut': choix, 'motifPerte': ?motif}),
      'Étape : ${_libellesStatut[choix]}.',
    );
  }

  Future<void> _passerEnClient() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Passer en client ?'),
        content: const Text('Le prospect devient un magasin client, avec ses contacts, notes et visites. Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Passer en client')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _executer(() => ref.read(dioProvider).post('/prospects/${widget.id}/convert'), 'Le prospect est maintenant un client.');
  }

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final async = ref.watch(ficheProspectProvider(widget.id));
    final p = async.value;
    final peutAgir = ref.watch(currentRoleProvider) != Role.direction;
    final prochaine = ref.watch(prochainesEtapesProvider).value?[widget.id];

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: p == null
            ? Column(children: [
                _EnteteVide(violet: violet),
                Expanded(
                  child: Center(
                    child: async.hasError
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Fiche indisponible : connectez-vous au réseau puis réessayez.', textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted)),
                          )
                        : const CircularProgressIndicator(),
                  ),
                ),
              ])
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ficheProspectProvider(widget.id));
                  await ref.read(ficheProspectProvider(widget.id).future).catchError((_) => p);
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Entete(
                      prospect: p,
                      violet: violet,
                      onAppeler: () => _appeler(p),
                      onItineraire: () => _itineraire(p),
                      onPlanifier: () => _planifier(p),
                      onNote: _note,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _CarteEtape(prospect: p, violet: violet),
                        const SizedBox(height: 22),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Expanded(child: Text('Timeline de prospection', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                          if (p.creeLe != null) Text('depuis le ${_dateCourte(p.creeLe!)}', style: const TextStyle(color: StatusColors.muted, fontSize: 12.5)),
                        ]),
                        const SizedBox(height: 12),
                        _Timeline(
                          evenements: [
                            if (prochaine != null)
                              EvenementProspect(
                                icone: Icons.event_outlined,
                                couleur: violet,
                                titre: 'RDV prévu',
                                detail: prochaineAction(prochaine),
                                date: prochaine.jour,
                              ),
                            ...p.evenements,
                          ],
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: p == null || !peutAgir
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _occupe ? null : () => _changerEtape(p),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Changer d\'étape'),
                    ),
                  ),
                  if (p.statut != 'GAGNE') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _occupe ? null : _passerEnClient,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Passer en client'),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
    );
  }
}

class _EnteteVide extends StatelessWidget {
  const _EnteteVide({required this.violet});

  final Color violet;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 24),
        decoration: BoxDecoration(color: violet, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
        alignment: Alignment.centerLeft,
        child: _Retour(),
      );
}

class _Retour extends StatelessWidget {
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.pop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      );
}

class _Entete extends StatelessWidget {
  const _Entete({required this.prospect, required this.violet, required this.onAppeler, required this.onItineraire, required this.onPlanifier, required this.onNote});

  final FicheProspect prospect;
  final Color violet;
  final VoidCallback onAppeler;
  final VoidCallback onItineraire;
  final VoidCallback onPlanifier;
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final p = prospect;
    final sousTitre = [
      ?p.raisonSociale,
      if (p.niveauClass != null) 'classe ${p.niveauClass}',
      [?p.codePostal, ?p.ville].join(' '),
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    final etape = p.groupe?.libelle ?? _libellesStatut[p.statut] ?? p.statut;
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 16),
      decoration: BoxDecoration(color: violet, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _Retour(),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFCEFC6), borderRadius: BorderRadius.circular(10)),
            child: Text('Prospect · $etape', style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ]),
        const SizedBox(height: 16),
        Text(
          '${p.enseigne}${p.ville == null ? '' : ' – ${p.ville}'}',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15),
        ),
        if (sousTitre.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sousTitre, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Action(icone: Icons.phone_outlined, libelle: 'Appeler', onTap: onAppeler)),
          const SizedBox(width: 8),
          Expanded(child: _Action(icone: Icons.navigation_outlined, libelle: 'Itinéraire', onTap: onItineraire)),
          const SizedBox(width: 8),
          Expanded(child: _Action(icone: Icons.calendar_today_outlined, libelle: 'Planifier', onTap: onPlanifier)),
          const SizedBox(width: 8),
          Expanded(child: _Action(icone: Icons.edit_outlined, libelle: 'Note', onTap: onNote)),
        ]),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icone, required this.libelle, required this.onTap});

  final IconData icone;
  final String libelle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(icone, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(libelle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ]),
        ),
      );
}

class _CarteEtape extends StatelessWidget {
  const _CarteEtape({required this.prospect, required this.violet});

  final FicheProspect prospect;
  final Color violet;

  @override
  Widget build(BuildContext context) {
    final p = prospect;
    const etapes = ['Fiche créée', 'À contacter', 'RDV pris', 'En négo', 'Référencé'];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Étape de prospection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(p.statut == 'PERDU' ? 'Perdu' : 'Probabilité ${p.probabilite} %', style: const TextStyle(color: StatusColors.muted, fontSize: 12.5)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < etapes.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 5, decoration: BoxDecoration(color: i < p.segments ? violet : const Color(0xFFE5E7EF), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 6),
                  Text(
                    etapes[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, fontWeight: i == p.segments - 1 ? FontWeight.w800 : FontWeight.w500, color: i == p.segments - 1 ? violet : StatusColors.muted),
                  ),
                ]),
              ),
            ],
          ]),
          const Divider(height: 24),
          Wrap(spacing: 18, runSpacing: 4, children: [
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Potentiel ', style: TextStyle(fontSize: 13, color: StatusColors.muted)),
              TextSpan(text: potentielCourt(p.potentiel), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ])),
            if (p.contact != null)
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Contact ', style: TextStyle(fontSize: 13, color: StatusColors.muted)),
                TextSpan(text: p.contact, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ])),
          ]),
        ]),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.evenements});

  final List<EvenementProspect> evenements;

  @override
  Widget build(BuildContext context) {
    if (evenements.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: EdgeInsets.all(24), child: Text('Aucune activité pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted))),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Column(children: [
          for (var i = 0; i < evenements.length; i++) _Ligne(evenement: evenements[i], derniere: i == evenements.length - 1),
        ]),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.evenement, required this.derniere});

  final EvenementProspect evenement;
  final bool derniere;

  @override
  Widget build(BuildContext context) {
    final e = evenement;
    final d = e.date;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 34,
          child: Column(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: e.couleur.withValues(alpha: .13), shape: BoxShape.circle),
              child: Icon(e.icone, size: 17, color: e.couleur),
            ),
            if (!derniere) Expanded(child: Container(width: 2, color: const Color(0xFFE5E7EF))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                const SizedBox(width: 8),
                Text('${_joursCourts[d.weekday - 1]} ${_dateCourte(d)}', style: const TextStyle(color: StatusColors.muted, fontSize: 12)),
              ]),
              if (e.detail != null) ...[
                const SizedBox(height: 2),
                Text(e.detail!, style: const TextStyle(color: StatusColors.muted, fontSize: 12.5)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Ouvre la fiche du magasin ou du prospect visé par une ligne de tournée. Faux (rien d'ouvert) pour une tâche
/// administrative, une ligne libre, ou une ligne dont le prospect n'est pas encore connu du serveur.
bool ouvrirFicheDeLigne(BuildContext context, EtapeTournee e) {
  final id = e.cibleId;
  if (id == null || e.enAttente) return false;
  switch (e.type) {
    case 'PROSPECT':
      context.push('/pilot/prospects/$id');
      return true;
    case 'CLIENT':
      context.push('/pilot/magasins/$id');
      return true;
  }
  return false;
}
