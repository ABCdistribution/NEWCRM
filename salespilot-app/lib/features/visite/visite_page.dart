import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import 'draft_repository.dart';
import 'visite_models.dart';
import 'visite_service.dart';

final _draftProvider =
    StreamProvider.autoDispose.family<VisiteDraft?, String>((ref, id) => ref.watch(draftRepositoryProvider).watch(id));

/// Avancement des envois de la visite (visite + photos), pour afficher « photos n sur N ».
final _envoiProvider = StreamProvider.autoDispose.family<List<OutboxItem>, ({String userId, List<String> ids})>(
  (ref, k) => ref.watch(outboxRepositoryProvider).watchByIdApks(k.userId, k.ids),
);

/// Visite : saisie (brouillon), contrôle et validation, puis suivi de l'envoi.
class VisitePage extends ConsumerStatefulWidget {
  const VisitePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<VisitePage> createState() => _VisitePageState();
}

class _VisitePageState extends ConsumerState<VisitePage> {
  late final VisiteService _service;
  VisiteDraft? _draft;
  VisiteData _data = const VisiteData();
  var _loaded = false;
  Timer? _debounce;
  final _commentaire = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _service = ref.read(visiteServiceProvider); // gardé pour sauvegarder à la fermeture (ref interdit dans dispose)
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flush(); // jamais de saisie perdue en quittant l'écran
    _commentaire.dispose();
    super.dispose();
  }

  bool get _editable => _draft?.state == VisiteState.brouillon;

  void _flush() {
    final d = _draft;
    if (d != null && _editable && _loaded) unawaited(_service.saveData(d, _data));
  }

  /// Applique une modification et l'écrit tout de suite sur le téléphone (aucun bouton « enregistrer »).
  void _update(VisiteData next, {bool immediate = true}) {
    setState(() => _data = next);
    _debounce?.cancel();
    if (immediate) {
      _flush();
    } else {
      _debounce = Timer(const Duration(milliseconds: 350), _flush);
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    final shot = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80); // compression avant envoi
    if (shot == null) return;
    // Copie dans le stockage de l'application : le fichier du sélecteur est temporaire.
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'visites'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, '${const Uuid().v4()}.jpg');
    await File(shot.path).copy(dest);
    _update(_data.copyWith(photos: [..._data.photos, dest]));
  }

  Future<void> _terminer(List<Question> questions) async {
    final d = _draft!;
    final controle = VisiteValidator.controle(_data, questions);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _SyntheseDialog(controle: controle, libelle: d.libelle),
    );
    if (ok != true || !mounted) return;
    _debounce?.cancel();
    await _service.saveData(d, _data);
    final latest = (await ref.read(draftRepositoryProvider).get(d.id))!;
    final bloquants = await _service.finish(latest, questions);
    if (!mounted) return;
    if (bloquants.isNotEmpty) return;
    ref.read(syncControllerProvider.notifier).run(); // part tout de suite si le réseau le permet
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visite validée. Envoi dès que le réseau le permet.')));
    context.go('/');
  }

  Future<void> _rouvrir() async {
    final d = _draft!;
    final ok = await _service.reopen(d);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cette visite est déjà envoyée : elle n\'est plus modifiable.')));
    } else {
      setState(() => _loaded = false); // recharge les données depuis le brouillon rouvert
    }
  }

  Future<void> _abandonner() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Abandonner cette visite ?'),
        content: const Text('Le brouillon et ses photos seront supprimés du téléphone. Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Garder')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: StatusColors.alert),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _debounce?.cancel();
    _loaded = false; // pas de sauvegarde à la fermeture
    await _service.abandon(_draft!);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_draftProvider(widget.id));
    final questions = ref.watch(questionnaireProvider).value ?? const <Question>[];

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Erreur : $e'))),
      data: (draft) {
        if (draft == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Visite introuvable.')));
        }
        _draft = draft;
        if (!_loaded) {
          _data = VisiteData.fromJson(jsonDecode(draft.dataJson) as Map<String, dynamic>);
          _commentaire.text = _data.commentaire;
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/')),
            title: Text(draft.libelle.isEmpty ? 'Visite' : draft.libelle, overflow: TextOverflow.ellipsis),
            actions: [
              if (_editable)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'abandon') _abandonner();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'abandon', child: Text('Abandonner le brouillon'))],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _EtatBandeau(draft: draft, data: _data, onRouvrir: _rouvrir),
              const SizedBox(height: 16),
              _section('Motif'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in motifsVisite)
                  ChoiceChip(
                    label: Text(m),
                    selected: _data.motif == m,
                    onSelected: _editable ? (_) => _update(_data.copyWith(motif: m)) : null,
                  ),
              ]),
              const SizedBox(height: 20),
              _section('Distribution numérique'),
              _DnGrid(data: _data, enabled: _editable, onChanged: _update),
              if (questions.isNotEmpty) ...[
                const SizedBox(height: 20),
                _section('Questionnaire'),
                for (final q in questions)
                  _QuestionField(
                    key: ValueKey('${draft.id}-${q.id}'),
                    question: q,
                    value: _data.reponses[q.id] ?? '',
                    enabled: _editable,
                    onChanged: (v) => _update(_data.copyWith(reponses: {..._data.reponses, q.id: v}), immediate: false),
                  ),
              ],
              const SizedBox(height: 20),
              _section('Commentaire'),
              TextField(
                controller: _commentaire,
                enabled: _editable,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(hintText: 'Observations sur la visite'),
                onChanged: (v) => _update(_data.copyWith(commentaire: v), immediate: false),
              ),
              const SizedBox(height: 12),
              _section('Photos (${_data.photos.length})'),
              _Photos(
                chemins: _data.photos,
                enabled: _editable,
                onAdd: _addPhoto,
                onRemove: (path) => _update(_data.copyWith(photos: _data.photos.where((x) => x != path).toList())),
              ),
            ],
          ),
          bottomNavigationBar: _editable
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () => _terminer(questions),
                      icon: const Icon(Icons.check),
                      label: const Text('Terminer la visite'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

/// Bandeau d'état : brouillon, terminée (en attente d'envoi, photos n sur N), synchronisée.
class _EtatBandeau extends ConsumerWidget {
  const _EtatBandeau({required this.draft, required this.data, required this.onRouvrir});

  final VisiteDraft draft;
  final VisiteData data;
  final VoidCallback onRouvrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = [draft.id, for (var i = 0; i < data.photos.length; i++) VisiteService.photoId(draft.id, i)];
    final envois = ref.watch(_envoiProvider((userId: draft.userId, ids: ids))).value ?? const <OutboxItem>[];
    final photosEnvoyees = envois.where((o) => o.kind == 'photo' && o.status == OutboxStatus.sent).length;
    final enErreur = envois.where((o) => o.status == OutboxStatus.error).toList();

    final (String label, Color color, IconData icon) = switch (draft.state) {
      VisiteState.terminee => ('Terminée — en attente d\'envoi', const Color(0xFF2563EB), Icons.schedule_send),
      VisiteState.synchronisee => ('Synchronisée', StatusColors.ok, Icons.cloud_done),
      _ => ('Brouillon — enregistré sur le téléphone', StatusColors.warn, Icons.edit_note),
    };

    return Card(
      color: color.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
          ]),
          if (draft.state == VisiteState.terminee && data.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Photos : $photosEnvoyees sur ${data.photos.length} envoyées'),
            ),
          for (final e in enErreur)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Envoi refusé : ${e.lastError ?? 'motif inconnu'}', style: const TextStyle(color: StatusColors.alert)),
            ),
          if (draft.state == VisiteState.terminee)
            TextButton.icon(onPressed: onRouvrir, icon: const Icon(Icons.edit), label: const Text('Rouvrir pour corriger')),
        ]),
      ),
    );
  }
}

class _SyntheseDialog extends StatelessWidget {
  const _SyntheseDialog({required this.controle, required this.libelle});

  final VisiteControle controle;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final ok = controle.peutValider;
    return AlertDialog(
      title: Text(ok ? 'Valider la visite ?' : 'Visite incomplète'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Questions répondues : ${controle.questionsRepondues} sur ${controle.questionsTotal}'),
        Text('Photos : ${controle.photos}'),
        if (!ok) ...[
          const SizedBox(height: 12),
          for (final b in controle.bloquants)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline, size: 18, color: StatusColors.alert),
                const SizedBox(width: 6),
                Expanded(child: Text(b)),
              ]),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Une fois validée, la visite part dès que le réseau le permet. Vous pourrez la rouvrir tant qu\'elle n\'est pas envoyée.'),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ok ? 'Continuer à saisir' : 'Corriger')),
        if (ok) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
      ],
    );
  }
}

class _DnGrid extends StatelessWidget {
  const _DnGrid({required this.data, required this.enabled, required this.onChanged});

  final VisiteData data;
  final bool enabled;
  final void Function(VisiteData, {bool immediate}) onChanged;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, int? value, VisiteData Function(int?) apply) => Expanded(
          child: TextFormField(
            key: ValueKey('$label-${enabled ? 'e' : 'r'}'),
            initialValue: value?.toString() ?? '',
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => onChanged(apply(int.tryParse(v)), immediate: false),
          ),
        );
    return Column(children: [
      Row(children: [
        field('ABC', data.dnAbc, (v) => v == null ? data.copyWith(clearDnAbc: true) : data.copyWith(dnAbc: v)),
        const SizedBox(width: 12),
        field('Concurrence', data.dnConcurrence, (v) => v == null ? data.copyWith(clearDnConcurrence: true) : data.copyWith(dnConcurrence: v)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        field('Gondole haute', data.dnGondoleHaute, (v) => v == null ? data.copyWith(clearDnGondoleHaute: true) : data.copyWith(dnGondoleHaute: v)),
        const SizedBox(width: 12),
        field('Gondole basse', data.dnGondoleBasse, (v) => v == null ? data.copyWith(clearDnGondoleBasse: true) : data.copyWith(dnGondoleBasse: v)),
      ]),
    ]);
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({super.key, required this.question, required this.value, required this.enabled, required this.onChanged});

  final Question question;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = question.obligatoire ? '${question.libelle} *' : question.libelle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (question.type) {
        'CASE_A_COCHER' => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            value: value == 'oui',
            onChanged: enabled ? (v) => onChanged(v ? 'oui' : 'non') : null,
          ),
        'NOTE_1_5' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (var n = 1; n <= 5; n++)
                ChoiceChip(label: Text('$n'), selected: value == '$n', onSelected: enabled ? (_) => onChanged('$n') : null),
            ]),
          ]),
        'NOMBRE' => TextFormField(
            initialValue: value,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
            onChanged: onChanged,
          ),
        _ => TextFormField(
            initialValue: value,
            enabled: enabled,
            maxLines: 2,
            decoration: InputDecoration(labelText: label),
            onChanged: onChanged,
          ),
      },
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.chemins, required this.enabled, required this.onAdd, required this.onRemove});

  final List<String> chemins;
  final bool enabled;
  final Future<void> Function(ImageSource) onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (chemins.isNotEmpty)
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chemins.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(chemins[i]), width: 96, height: 96, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(width: 96, height: 96, color: Colors.black12, child: const Icon(Icons.broken_image))),
              ),
              if (enabled)
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () => onRemove(chemins[i]),
                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
            ]),
          ),
        ),
      if (enabled) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => onAdd(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Prendre une photo'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Choisir dans la galerie',
            onPressed: () => onAdd(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ]),
      ],
    ]);
  }
}
