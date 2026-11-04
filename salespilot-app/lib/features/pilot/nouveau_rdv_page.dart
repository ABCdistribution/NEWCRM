import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_transport.dart';
import '../../core/theme/app_theme.dart';
import '../prechargement.dart';
import '../providers.dart';
import 'pilot_planning_page.dart';
import 'tournee_etapes.dart';

const _joursLongs = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Cible d'une ligne du rapport : un magasin, un prospect, du texte libre (client ou lieu) ou une tâche administrative.
enum _Cible { client, prospect, libre, adm }

class _Choix {
  const _Choix({required this.id, required this.nom, this.ville});
  final String id;
  final String nom;
  final String? ville;
}

/// « Saisir le rapport » d'ABC Pilot (bouton de l'onglet Tournée) : une ligne du rapport d'activité (client ou ADM,
/// adresse, visite simple / accompagnement, RDV, heure, soirée étape, observations), comme sur le web.
///
/// Création : la ligne est écrite sur le téléphone puis envoyée à `POST /tournees` (jamais perdue si le réseau manque,
/// sans doublon grâce à l'idApk). Modification ([etape] fournie) : appel direct au serveur, qui refuse une semaine
/// validée ; une ligne pas encore envoyée ne se modifie pas.
class NouveauRdvPage extends ConsumerStatefulWidget {
  const NouveauRdvPage({super.key, this.date, this.etape, this.prospectId, this.clientId, this.prospectNom, this.prospectVille});

  /// Jour proposé au départ (celui affiché dans la tournée).
  final DateTime? date;

  /// Prospect ou magasin déjà choisi (« Planifier » depuis sa fiche) : la cible démarre sur lui. `prospectNom` et
  /// `prospectVille` portent le nom et la ville de l'un comme de l'autre.
  final String? prospectId;
  final String? clientId;
  final String? prospectNom;
  final String? prospectVille;

  /// Ligne existante à modifier ou supprimer.
  final EtapeTournee? etape;

  @override
  ConsumerState<NouveauRdvPage> createState() => _NouveauRdvPageState();
}

class _NouveauRdvPageState extends ConsumerState<NouveauRdvPage> {
  final _note = TextEditingController();
  final _libelle = TextEditingController();
  final _adresseLigne = TextEditingController();
  final _lieu = TextEditingController();
  final _soireeAdresse = TextEditingController();
  late DateTime _date;
  TimeOfDay? _heure;
  _Cible _cible = _Cible.client;
  _Choix? _choix;
  bool _visiteSimple = true;
  bool _accompagnement = false;
  bool _rdv = false;
  bool _soiree = false;
  bool _fait = false;
  bool _busy = false;
  String? _erreur;

  bool get _edition => widget.etape != null;

  @override
  void initState() {
    super.initState();
    final e = widget.etape;
    if (e == null) {
      final d = widget.date ?? DateTime.now();
      _date = DateTime(d.year, d.month, d.day);
      if (widget.prospectId != null) {
        _cible = _Cible.prospect;
        _choix = _Choix(id: widget.prospectId!, nom: widget.prospectNom ?? 'Prospect', ville: widget.prospectVille);
      } else if (widget.clientId != null) {
        _cible = _Cible.client;
        _choix = _Choix(id: widget.clientId!, nom: widget.prospectNom ?? 'Magasin', ville: widget.prospectVille);
      }
      return;
    }
    _date = e.jour;
    if (e.heure != null) {
      final p = e.heure!.split(':');
      _heure = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    _cible = switch (e.type) {
      'PROSPECT' => _Cible.prospect,
      'ADM' => _Cible.adm,
      'LIBRE' => _Cible.libre,
      _ => _Cible.client,
    };
    _libelle.text = e.libelle ?? '';
    _adresseLigne.text = e.adresse ?? '';
    _note.text = e.note ?? '';
    _visiteSimple = e.visiteSimple;
    _accompagnement = e.accompagnement;
    _rdv = e.rdv;
    _soiree = e.soireeEtape;
    _lieu.text = e.soireeLieu ?? '';
    _soireeAdresse.text = e.soireeAdresse ?? '';
    _fait = e.fait;
  }

  @override
  void dispose() {
    for (final c in [_note, _libelle, _adresseLigne, _lieu, _soireeAdresse]) {
      c.dispose();
    }
    super.dispose();
  }

  String _libelleDate(DateTime d) => '${_joursLongs[d.weekday - 1]} ${d.day} ${_moisCourts[d.month - 1]} ${d.year}';

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _choisirHeure() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _heure ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (h != null) setState(() => _heure = h);
  }

  Future<void> _choisirCible() async {
    final choix = await showModalBottomSheet<_Choix>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: .85, child: _SelecteurCible(cible: _cible)),
    );
    if (choix != null) setState(() => _choix = choix);
  }

  String? get _heureTexte => _heure == null ? null : '${_heure!.hour.toString().padLeft(2, '0')}:${_heure!.minute.toString().padLeft(2, '0')}';

  /// « yyyy-mm-dd » ou « yyyy-mm-ddTHH:mm:00 » : la date de passage telle que le serveur la reçoit.
  String get _datePassage => _heureTexte == null ? jourIso(_date) : '${jourIso(_date)}T$_heureTexte:00';

  Future<void> _ajouter() async {
    if (_cible == _Cible.libre && _libelle.text.trim().isEmpty) {
      setState(() => _erreur = 'Saisissez le client ou le lieu.');
      return;
    }
    if ((_cible == _Cible.client || _cible == _Cible.prospect) && _choix == null) {
      setState(() => _erreur = _cible == _Cible.client ? 'Choisissez un magasin.' : 'Choisissez un prospect.');
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    final idApk = const Uuid().v4();
    final note = _note.text.trim();
    final adresse = _adresseLigne.text.trim();
    try {
      await ref.read(outboxRepositoryProvider).enqueue(
        userId: userId,
        kind: OutboxKind.etapeTournee,
        idApk: idApk,
        payload: {
          'idApk': idApk,
          'datePassage': _datePassage,
          'visiteSimple': _visiteSimple,
          'accompagnement': _accompagnement,
          'rdv': _rdv,
          'soireeEtape': _soiree,
          if (_soiree && _lieu.text.trim().isNotEmpty) 'soireeLieu': _lieu.text.trim(),
          if (_soiree && _soireeAdresse.text.trim().isNotEmpty) 'soireeAdresse': _soireeAdresse.text.trim(),
          if (note.isNotEmpty) 'note': note,
          if (adresse.isNotEmpty) 'adresse': adresse,
          if (_cible == _Cible.adm)
            'adm': true
          else if (_cible == _Cible.client)
            'clientId': _choix!.id
          else if (_cible == _Cible.prospect)
            'prospectId': _choix!.id
          else
            'libelle': _libelle.text.trim(),
          '_titre': switch (_cible) {
            _Cible.adm => 'Administratif',
            _Cible.libre => _libelle.text.trim(),
            _ => _choix!.nom,
          },
          if (_choix?.ville != null && (_cible == _Cible.client || _cible == _Cible.prospect)) '_ville': _choix!.ville,
        },
      );
      ref.read(syncControllerProvider.notifier).run();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Ligne ajoutée au rapport. Envoi dès que le réseau le permet.')));
      context.pop(_date);
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Message d'une modification qui n'a PAS été enregistrée : sans réseau, on le dit (la saisie n'est pas gardée).
  String _messageModification(Object e) =>
      e is DioException && e.response == null ? 'Connexion requise pour modifier une ligne déjà enregistrée.' : errorMessage(e);

  Future<void> _enregistrer() async {
    final e = widget.etape!;
    if (_cible == _Cible.libre && _libelle.text.trim().isEmpty) {
      setState(() => _erreur = 'Saisissez le client ou le lieu.');
      return;
    }
    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      await ref.read(rapportActionsProvider).modifierEtape(
        e.id,
        {
          'datePassage': _datePassage,
          'note': _note.text.trim(),
          'adresse': _adresseLigne.text.trim(),
          if (_cible == _Cible.libre) 'libelle': _libelle.text.trim(),
          'visiteSimple': _visiteSimple,
          'accompagnement': _accompagnement,
          'rdv': _rdv,
          'soireeEtape': _soiree,
          'soireeLieu': _lieu.text.trim(),
          'soireeAdresse': _soireeAdresse.text.trim(),
          'fait': _fait,
        },
        lundiDe(_date),
      );
      // La ligne a pu changer de semaine : on relit aussi l'ancienne.
      if (lundiDe(e.jour) != lundiDe(_date)) unawaited(ref.read(miseAJourLocaleProvider).etapes(lundiDe(e.jour)));
      if (mounted) context.pop(_date);
    } on Object catch (err) {
      if (mounted) setState(() => _erreur = _messageModification(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette ligne ?'),
        content: const Text('Elle sera retirée de la tournée réalisée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      await ref.read(rapportActionsProvider).supprimerEtape(widget.etape!.id, lundiDe(widget.etape!.jour));
      if (mounted) context.pop(widget.etape!.jour);
    } on Object catch (err) {
      if (mounted) setState(() => _erreur = _messageModification(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SpacePalette.pilot;
    final theme = Theme.of(context);
    final titreCible = switch (_cible) {
      _Cible.client => 'Magasin',
      _Cible.prospect => 'Prospect',
      _ => '',
    };

    Widget section(String label, Widget enfant) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StatusColors.muted)),
            const SizedBox(height: 8),
            enfant,
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(_edition ? 'Modifier la ligne' : 'Saisir le rapport')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
              section(
                _edition ? 'Ligne' : 'Pour',
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_edition)
                    Text(
                      '${widget.etape!.titre}${widget.etape!.ville == null ? '' : ' – ${widget.etape!.ville}'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    )
                  else
                    SegmentedButton<_Cible>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _Cible.client, label: Text('Magasin')),
                        ButtonSegment(value: _Cible.prospect, label: Text('Prospect')),
                        ButtonSegment(value: _Cible.libre, label: Text('Libre')),
                        ButtonSegment(value: _Cible.adm, label: Text('ADM')),
                      ],
                      selected: {_cible},
                      onSelectionChanged: (s) => setState(() {
                        _cible = s.first;
                        _choix = null;
                      }),
                    ),
                  if (!_edition && (_cible == _Cible.client || _cible == _Cible.prospect)) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _choisirCible,
                      icon: Icon(_cible == _Cible.client ? Icons.storefront_outlined : Icons.person_search_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _choix == null ? 'Choisir un ${titreCible.toLowerCase()}' : '${_choix!.nom}${_choix!.ville == null ? '' : ' · ${_choix!.ville}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  if (_cible == _Cible.libre) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _libelle,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Client ou lieu *', counterText: ''),
                    ),
                  ],
                  if (_cible != _Cible.adm) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _adresseLigne,
                      maxLength: 300,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Adresse', counterText: ''),
                    ),
                  ],
                ]),
              ),
              section(
                'Date et heure',
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(onPressed: _choisirDate, icon: const Icon(Icons.calendar_today_outlined, size: 18), label: Text(_libelleDate(_date))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _choisirHeure,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(_heure == null ? '--:--' : _heure!.format(context)),
                    ),
                  ),
                  if (_heure != null) IconButton(tooltip: 'Sans heure précise', onPressed: () => setState(() => _heure = null), icon: const Icon(Icons.close, size: 18)),
                ]),
              ),
              section(
                'Type de passage',
                Wrap(spacing: 4, runSpacing: 0, children: [
                  _Case(
                    label: 'Visite simple',
                    valeur: _visiteSimple,
                    onChanged: (v) => setState(() {
                      _visiteSimple = v;
                      if (v) _accompagnement = false;
                    }),
                  ),
                  _Case(
                    label: 'Accompagnement promoteur',
                    valeur: _accompagnement,
                    onChanged: (v) => setState(() {
                      _accompagnement = v;
                      if (v) _visiteSimple = false;
                    }),
                  ),
                  _Case(label: 'RDV', valeur: _rdv, onChanged: (v) => setState(() => _rdv = v)),
                ]),
              ),
              section(
                'Soirée étape',
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [ButtonSegment(value: true, label: Text('Oui')), ButtonSegment(value: false, label: Text('Non'))],
                    selected: {_soiree},
                    onSelectionChanged: (s) => setState(() => _soiree = s.first),
                  ),
                  if (_soiree) ...[
                    const SizedBox(height: 10),
                    TextField(controller: _lieu, maxLength: 200, decoration: const InputDecoration(labelText: 'Lieu de l\'étape (ville, hôtel…)', counterText: '')),
                    const SizedBox(height: 10),
                    TextField(controller: _soireeAdresse, maxLength: 300, decoration: const InputDecoration(labelText: 'Adresse de l\'étape', counterText: '')),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Lieu et adresse sont obligatoires pour enregistrer la prévision et valider le rapport.',
                        style: TextStyle(fontSize: 12, color: StatusColors.muted),
                      ),
                    ),
                  ],
                ]),
              ),
              section(
                'Observations',
                TextField(controller: _note, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'Observations')),
              ),
              if (_edition)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visite effectuée'),
                  value: _fait,
                  onChanged: (v) => setState(() => _fait = v),
                ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_erreur!, style: theme.textTheme.bodyMedium?.copyWith(color: StatusColors.alert), semanticsLabel: 'Erreur : $_erreur'),
                ),
              if (_edition)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: _busy ? null : _supprimer,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer la ligne'),
                    style: TextButton.styleFrom(foregroundColor: StatusColors.alert),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              TextButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Annuler')),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : (_edition ? _enregistrer : _ajouter),
                  style: FilledButton.styleFrom(backgroundColor: p.bouton, foregroundColor: p.surBouton),
                  icon: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_edition ? 'Enregistrer' : 'Ajouter au planning'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({required this.label, required this.valeur, required this.onChanged});

  final String label;
  final bool valeur;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!valeur),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(value: valeur, onChanged: (v) => onChanged(v ?? false)),
          Padding(padding: const EdgeInsets.only(right: 12), child: Text(label)),
        ]),
      );
}

/// Choix du magasin (liste du téléphone, utilisable hors ligne) ou du prospect (recherche sur le serveur).
class _SelecteurCible extends ConsumerStatefulWidget {
  const _SelecteurCible({required this.cible});

  final _Cible cible;

  @override
  ConsumerState<_SelecteurCible> createState() => _SelecteurCibleState();
}

class _SelecteurCibleState extends ConsumerState<_SelecteurCible> {
  String _q = '';
  Timer? _attente;
  List<_Choix> _prospects = const [];
  bool _charge = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (widget.cible == _Cible.prospect) _chercher('');
  }

  @override
  void dispose() {
    _attente?.cancel();
    super.dispose();
  }

  void _saisie(String v) {
    setState(() => _q = v);
    if (widget.cible != _Cible.prospect) return;
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 350), () => _chercher(v));
  }

  Future<void> _chercher(String v) async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final res = await ref.read(dioProvider).get<Map<String, dynamic>>(
        '/prospects',
        queryParameters: {'limit': 30, if (v.trim().isNotEmpty) 'search': v.trim()},
      );
      final data = ((res.data?['data'] as List?) ?? const []).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() => _prospects = [
            for (final p in data)
              _Choix(
                id: p['id'] as String,
                nom: ((p['enseigne'] as String?)?.trim().isNotEmpty ?? false) ? p['enseigne'] as String : (p['raisonSociale'] as String? ?? 'Sans nom'),
                ville: p['ville'] as String?,
              ),
          ]);
    } on Object {
      if (mounted) setState(() => _erreur = 'La recherche de prospects demande une connexion au serveur.');
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estClient = widget.cible == _Cible.client;
    final List<_Choix> liste;
    if (estClient) {
      final q = _q.trim().toLowerCase();
      final magasins = ref.watch(magasinsProvider).value?.value ?? const [];
      liste = [
        for (final m in magasins)
          if (q.isEmpty || m.enseigne.toLowerCase().contains(q) || (m.ville ?? '').toLowerCase().contains(q) || m.codeAs400.toLowerCase().contains(q))
            _Choix(id: m.id, nom: m.enseigne, ville: m.ville),
      ];
    } else {
      liste = _prospects;
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          autofocus: true,
          onChanged: _saisie,
          decoration: InputDecoration(
            hintText: estClient ? 'Enseigne, ville ou code magasin' : 'Enseigne ou raison sociale',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
      if (_charge) const LinearProgressIndicator(minHeight: 2),
      if (_erreur != null) Padding(padding: const EdgeInsets.all(16), child: Text(_erreur!, style: const TextStyle(color: StatusColors.muted))),
      Expanded(
        child: liste.isEmpty && !_charge && _erreur == null
            ? const Center(child: Text('Aucun résultat.', style: TextStyle(color: StatusColors.muted)))
            : ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final c = liste[i];
                  return ListTile(
                    title: Text(c.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: c.ville == null ? null : Text(c.ville!),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
      ),
    ]);
  }
}
