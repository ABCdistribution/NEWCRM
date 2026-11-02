import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_transport.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import 'tournee_etapes.dart';

const _joursLongs = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Cible d'un rendez-vous : un magasin, un prospect ou une tâche administrative (comme sur le web).
enum _Cible { client, prospect, adm }

class _Choix {
  const _Choix({required this.id, required this.nom, this.ville});
  final String id;
  final String nom;
  final String? ville;
}

/// « Saisir le rapport » d'ABC Pilot (bouton de l'onglet Tournée) : formulaire de qualification d'une étape (date, heure, type de passage, RDV, soirée
/// étape, observations), identique à la fenêtre « Planifier » du web. L'étape est écrite sur le téléphone puis envoyée
/// à `POST /tournees` : jamais perdue si le réseau manque, sans doublon grâce à l'idApk.
class NouveauRdvPage extends ConsumerStatefulWidget {
  const NouveauRdvPage({super.key, this.date});

  /// Jour proposé au départ (celui affiché dans le planning).
  final DateTime? date;

  @override
  ConsumerState<NouveauRdvPage> createState() => _NouveauRdvPageState();
}

class _NouveauRdvPageState extends ConsumerState<NouveauRdvPage> {
  final _note = TextEditingController();
  final _lieu = TextEditingController();
  final _adresse = TextEditingController();
  late DateTime _date;
  TimeOfDay? _heure;
  _Cible _cible = _Cible.client;
  _Choix? _choix;
  bool _visiteSimple = true;
  bool _accompagnement = false;
  bool _rdv = false;
  bool _soiree = false;
  bool _busy = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final d = widget.date ?? DateTime.now();
    _date = DateTime(d.year, d.month, d.day);
  }

  @override
  void dispose() {
    _note.dispose();
    _lieu.dispose();
    _adresse.dispose();
    super.dispose();
  }

  String _libelleDate(DateTime d) => '${_joursLongs[d.weekday - 1]} ${d.day} ${_moisCourts[d.month - 1]} ${d.year}';

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
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

  Future<void> _ajouter() async {
    if (_cible != _Cible.adm && _choix == null) {
      setState(() => _erreur = _cible == _Cible.client ? 'Choisissez un magasin.' : 'Choisissez un prospect.');
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    final jour = jourIso(_date);
    final heure = _heure == null ? null : '${_heure!.hour.toString().padLeft(2, '0')}:${_heure!.minute.toString().padLeft(2, '0')}';
    final idApk = const Uuid().v4();
    final note = _note.text.trim();
    try {
      await ref.read(outboxRepositoryProvider).enqueue(
        userId: userId,
        kind: OutboxKind.etapeTournee,
        idApk: idApk,
        payload: {
          'idApk': idApk,
          'datePassage': heure == null ? jour : '${jour}T$heure:00',
          'visiteSimple': _visiteSimple,
          'accompagnement': _accompagnement,
          'rdv': _rdv,
          'soireeEtape': _soiree,
          if (_soiree && _lieu.text.trim().isNotEmpty) 'soireeLieu': _lieu.text.trim(),
          if (_soiree && _adresse.text.trim().isNotEmpty) 'soireeAdresse': _adresse.text.trim(),
          if (note.isNotEmpty) 'note': note,
          if (_cible == _Cible.adm)
            'adm': true
          else if (_cible == _Cible.client)
            'clientId': _choix!.id
          else
            'prospectId': _choix!.id,
          '_titre': _cible == _Cible.adm ? 'Administratif' : _choix!.nom,
          if (_choix?.ville != null) '_ville': _choix!.ville,
        },
      );
      ref.read(syncControllerProvider.notifier).run();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Rendez-vous ajouté au planning. Envoi dès que le réseau le permet.')));
      context.pop(_date);
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = errorMessage(e));
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
      _Cible.adm => 'Étape administrative',
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
      appBar: AppBar(title: const Text('Saisir le rapport')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
              section(
                'Pour',
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SegmentedButton<_Cible>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: _Cible.client, label: Text('Magasin')),
                      ButtonSegment(value: _Cible.prospect, label: Text('Prospect')),
                      ButtonSegment(value: _Cible.adm, label: Text('ADM')),
                    ],
                    selected: {_cible},
                    onSelectionChanged: (s) => setState(() {
                      _cible = s.first;
                      _choix = null;
                    }),
                  ),
                  if (_cible != _Cible.adm) ...[
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
                    TextField(controller: _adresse, maxLength: 300, decoration: const InputDecoration(labelText: 'Adresse de l\'étape', counterText: '')),
                  ],
                ]),
              ),
              section(
                'Observations',
                TextField(controller: _note, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'Observations')),
              ),
              if (_erreur != null)
                Text(_erreur!, style: theme.textTheme.bodyMedium?.copyWith(color: StatusColors.alert), semanticsLabel: 'Erreur : $_erreur'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              TextButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Annuler')),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _ajouter,
                  style: FilledButton.styleFrom(backgroundColor: p.bouton, foregroundColor: p.surBouton),
                  icon: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Ajouter au planning'),
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
