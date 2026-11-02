import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_transport.dart';
import '../../core/theme/app_theme.dart';
import 'prospects_pipeline.dart';

/// Mêmes libellés que le web (création de prospect). « Perdu » n'est pas proposé : on ne crée pas un prospect déjà perdu.
const _etapes = {
  'NOUVEAU': 'Fiche créée',
  'CONTACTE': 'Prise de contact',
  'PROPOSITION': 'Proposition',
  'VISITE': 'Visite',
  'NEGOCIATION': 'Négociation',
  'GAGNE': 'Gagné',
};
const _sources = {'SALON': 'Salon', 'RECOMMANDATION': 'Recommandation', 'TERRAIN': 'Terrain', 'WEB': 'Web'};
const _classes = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

/// « Nouveau prospect » d'ABC Pilot : identité et qualification, comme sur le web. Le prospect est écrit sur le
/// téléphone puis envoyé à `POST /prospects/apk` (idempotent) : jamais perdu si le réseau manque, sans doublon.
class NouveauProspectPage extends ConsumerStatefulWidget {
  const NouveauProspectPage({super.key});

  @override
  ConsumerState<NouveauProspectPage> createState() => _NouveauProspectPageState();
}

class _NouveauProspectPageState extends ConsumerState<NouveauProspectPage> {
  final _form = GlobalKey<FormState>();
  final _enseigne = TextEditingController();
  final _raisonSociale = TextEditingController();
  final _ville = TextEditingController();
  final _codePostal = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _probabilite = TextEditingController();
  final _potentiel = TextEditingController();
  String? _secteurId;
  String? _source;
  String? _classe;
  String _etape = 'NOUVEAU';
  bool _busy = false;
  String? _erreur;

  @override
  void dispose() {
    for (final c in [_enseigne, _raisonSociale, _ville, _codePostal, _telephone, _email, _probabilite, _potentiel]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _creer() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    String? texte(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final idApk = const Uuid().v4();
    try {
      await ref.read(outboxRepositoryProvider).enqueue(
        userId: userId,
        kind: OutboxKind.prospect,
        idApk: idApk,
        payload: {
          'idApk': idApk,
          'enseigne': _enseigne.text.trim(),
          'raisonSociale': _raisonSociale.text.trim(),
          if (texte(_ville) != null) 'ville': texte(_ville),
          if (texte(_codePostal) != null) 'codePostal': texte(_codePostal),
          if (texte(_telephone) != null) 'telephone': texte(_telephone),
          if (texte(_email) != null) 'email': texte(_email),
          if (_secteurId != null) 'secteurId': _secteurId,
          if (_source != null) 'source': _source,
          if (_classe != null) 'niveauClass': _classe,
          'statut': _etape,
          if (texte(_probabilite) != null) 'probabilite': int.parse(texte(_probabilite)!),
          if (texte(_potentiel) != null) 'potentielCaAnnuel': num.parse(texte(_potentiel)!.replaceAll(',', '.')),
        },
      );
      ref.read(syncControllerProvider.notifier).run();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Prospect créé. Envoi dès que le réseau le permet.')));
      context.pop(true);
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SpacePalette.pilot;
    final secteurs = ref.watch(secteursProspectProvider).value ?? const <SecteurChoix>[];

    Widget champ(String label, TextEditingController c,
            {String? hint, bool requis = false, TextInputType? clavier, List<TextInputFormatter>? formats, String? Function(String?)? valider}) =>
        TextFormField(
          controller: c,
          keyboardType: clavier,
          inputFormatters: formats,
          textCapitalization: clavier == null ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: InputDecoration(labelText: requis ? '$label *' : label, hintText: hint),
          validator: valider ?? (requis ? (v) => (v ?? '').trim().isEmpty ? '$label requis' : null : null),
        );

    Widget liste<T>(String label, T? valeur, List<DropdownMenuItem<T?>> items, ValueChanged<T?> onChanged) => DropdownButtonFormField<T?>(
          initialValue: valeur,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: items,
          onChanged: onChanged,
        );

    Widget section(String titre, List<Widget> enfants) => Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(titre, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: p.accent)),
              const SizedBox(height: 12),
              ...enfants,
            ]),
          ),
        );

    Widget deux(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ]);

    const espace = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nouveau prospect', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('* champs obligatoires', style: TextStyle(fontSize: 12, color: StatusColors.muted, fontWeight: FontWeight.w400)),
        ]),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                section('IDENTITÉ', [
                  champ('Enseigne', _enseigne, hint: 'Ex. Super Proxi Lunel', requis: true),
                  espace,
                  champ('Raison sociale', _raisonSociale, hint: 'Ex. SUPERMARCHÉ DUPONT SAS', requis: true),
                  espace,
                  deux(champ('Ville', _ville), champ('Code postal', _codePostal, clavier: TextInputType.number)),
                  espace,
                  deux(
                    champ('Téléphone', _telephone, clavier: TextInputType.phone),
                    champ(
                      'Email',
                      _email,
                      clavier: TextInputType.emailAddress,
                      valider: (v) {
                        final t = (v ?? '').trim();
                        return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Email invalide';
                      },
                    ),
                  ),
                ]),
                section('QUALIFICATION', [
                  deux(
                    liste<String>('Secteur', _secteurId, [
                      const DropdownMenuItem(value: null, child: Text('— aucun —')),
                      for (final s in secteurs) DropdownMenuItem(value: s.id, child: Text(s.nom, overflow: TextOverflow.ellipsis)),
                    ], (v) => setState(() => _secteurId = v)),
                    liste<String>('Source', _source, [
                      const DropdownMenuItem(value: null, child: Text('— non précisée —', overflow: TextOverflow.ellipsis)),
                      for (final e in _sources.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ], (v) => setState(() => _source = v)),
                  ),
                  espace,
                  deux(
                    liste<String>('Classe du magasin', _classe, [
                      const DropdownMenuItem(value: null, child: Text('— non renseignée —', overflow: TextOverflow.ellipsis)),
                      for (final c in _classes) DropdownMenuItem(value: c, child: Text('Classe $c')),
                    ], (v) => setState(() => _classe = v)),
                    liste<String>('Étape', _etape, [
                      for (final e in _etapes.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                    ], (v) => setState(() => _etape = v ?? 'NOUVEAU')),
                  ),
                  espace,
                  deux(
                    champ(
                      'Probabilité (%)',
                      _probabilite,
                      clavier: TextInputType.number,
                      formats: [FilteringTextInputFormatter.digitsOnly],
                      valider: (v) {
                        final t = (v ?? '').trim();
                        return t.isEmpty || (int.tryParse(t) ?? 101) <= 100 ? null : 'Entre 0 et 100';
                      },
                    ),
                    champ(
                      'Potentiel CA/an (€)',
                      _potentiel,
                      clavier: const TextInputType.numberWithOptions(decimal: true),
                      formats: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      valider: (v) {
                        final t = (v ?? '').trim();
                        return t.isEmpty || num.tryParse(t.replaceAll(',', '.')) != null ? null : 'Montant invalide';
                      },
                    ),
                  ),
                ]),
                if (_erreur != null)
                  Text(_erreur!, style: const TextStyle(color: StatusColors.alert), semanticsLabel: 'Erreur : $_erreur'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Annuler'))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _creer,
                    style: FilledButton.styleFrom(backgroundColor: p.bouton, foregroundColor: p.surBouton),
                    icon: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.add),
                    label: const Text('Créer le prospect'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
