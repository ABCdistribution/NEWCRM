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
import '../../core/theme/app_theme.dart';
import 'draft_repository.dart';
import 'visite_models.dart';

final _draftProvider =
    StreamProvider.autoDispose.family<VisiteDraft?, String>((ref, id) => ref.watch(draftRepositoryProvider).watch(id));

enum EtatEtape { fait, enCours, aFaire }

/// Une étape du parcours de visite, avec ce qu'on peut en dire d'après la saisie (null = rien à afficher).
class EtapeVisite {
  const EtapeVisite(this.numero, this.libelle, this.etat, {this.detail});

  final int numero;
  final String libelle;
  final EtatEtape etat;
  final String? detail;
}

/// Les six étapes de la maquette. Seules celles qui ont une donnée dans la saisie actuelle sont calculées ;
/// les autres restent « à faire » jusqu'à ce que leur écran soit défini.
List<EtapeVisite> etapesDe(VisiteData d, {required DateTime demarree}) {
  final fait = <int, String?>{
    1: _heure(demarree), // le démarrage de la visite vaut check-in tant que la géolocalisation n'est pas posée
    if (d.photos.isNotEmpty) 4: '${d.photos.length} photo${d.photos.length > 1 ? 's' : ''}',
    if (d.commentaire.trim().isNotEmpty) 6: null,
  };
  const libelles = [
    'Check-in géolocalisé',
    'Relevé linéaire',
    'Contrôle des ruptures',
    'Photos avant / après',
    'Relevé de prix concurrence',
    'Compte-rendu & signature',
  ];
  final courante = [for (var n = 1; n <= 6; n++) n].firstWhere((n) => !fait.containsKey(n), orElse: () => 0);
  return [
    for (var n = 1; n <= 6; n++)
      EtapeVisite(
        n,
        libelles[n - 1],
        fait.containsKey(n) ? EtatEtape.fait : (n == courante ? EtatEtape.enCours : EtatEtape.aFaire),
        detail: fait.containsKey(n) ? fait[n] : (n == courante ? 'En cours' : null),
      ),
  ];
}

String _heure(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Écran de visite : progression, étapes et photos du rayon. La saisie détaillée est sur `/visite/:id/saisie`.
class VisiteEtapesPage extends ConsumerWidget {
  const VisiteEtapesPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_draftProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Erreur : $e'))),
      data: (draft) {
        if (draft == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Visite introuvable.')));
        return _Contenu(draft: draft);
      },
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.draft});

  final VisiteDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = VisiteData.fromJson(jsonDecode(draft.dataJson) as Map<String, dynamic>);
    final etapes = etapesDe(data, demarree: draft.createdAt);
    final faites = etapes.where((e) => e.etat == EtatEtape.fait).length;
    final editable = draft.state == VisiteState.brouillon;
    final accent = Theme.of(context).colorScheme.primary;
    final minutes = DateTime.now().difference(draft.createdAt).inMinutes;

    void saisie() => context.push('/visite/${draft.id}/saisie');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  onTap: () => context.canPop() ? context.pop() : context.go('/'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF1F4FA), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(draft.libelle.isEmpty ? 'Visite' : draft.libelle,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 2),
                    Text(
                      'Visite démarrée à ${_heure(draft.createdAt)} · ${minutes < 1 ? '< 1' : minutes} min',
                      style: const TextStyle(fontSize: 12, color: StatusColors.muted),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                _Badge(state: draft.state),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: Text('Progression de la visite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Text('$faites / ${etapes.length} étapes', style: const TextStyle(fontSize: 12, color: StatusColors.muted)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: faites / etapes.length,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE3E8F3),
                  color: accent,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              _Carte(children: [
                for (var i = 0; i < etapes.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _LigneEtape(etape: etapes[i], accent: accent, onTap: saisie),
                ],
              ]),
              const SizedBox(height: 16),
              _PhotosRayon(draft: draft, data: data, editable: editable),
            ]),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('La commande depuis la visite arrive bientôt.'))),
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: const Text('Commander'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: accent.withValues(alpha: .08),
                  foregroundColor: accent,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: saisie,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(editable ? 'Étape suivante' : 'Voir la visite'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      VisiteState.terminee => ('À envoyer', const Color(0xFF2563EB)),
      VisiteState.synchronisee => ('Envoyée', StatusColors.ok),
      _ => ('En cours', StatusColors.ok),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: children),
      );
}

class _LigneEtape extends StatelessWidget {
  const _LigneEtape({required this.etape, required this.accent, required this.onTap});

  final EtapeVisite etape;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enCours = etape.etat == EtatEtape.enCours;
    final fait = etape.etat == EtatEtape.fait;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          SizedBox(
            width: 26,
            height: 26,
            child: fait
                ? const DecoratedBox(
                    decoration: BoxDecoration(color: StatusColors.ok, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: enCours ? accent : const Color(0xFFCBD2E0), width: 1.5),
                    ),
                    child: Center(
                      child: Text('${etape.numero}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: enCours ? accent : StatusColors.muted)),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              etape.libelle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: fait || enCours ? FontWeight.w700 : FontWeight.w500,
                color: enCours ? accent : (fait ? null : StatusColors.muted),
              ),
            ),
          ),
          if (etape.detail != null) Text(etape.detail!, style: const TextStyle(fontSize: 12, color: StatusColors.muted)),
        ]),
      ),
    );
  }
}

/// Photos prises pendant la visite, avec une tuile pour en ajouter.
class _PhotosRayon extends ConsumerWidget {
  const _PhotosRayon({required this.draft, required this.data, required this.editable});

  final VisiteDraft draft;
  final VisiteData data;
  final bool editable;

  Future<void> _ajouter(WidgetRef ref) async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (shot == null) return;
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'visites'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, '${const Uuid().v4()}.jpg');
    await File(shot.path).copy(dest);
    await ref.read(visiteServiceProvider).saveData(draft, data.copyWith(photos: [...data.photos, dest]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    return _Carte(children: [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Row(children: [
          const Expanded(child: Text('Photos du rayon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          Text('${data.photos.length} photo${data.photos.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: StatusColors.muted)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          height: 74,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final chemin in data.photos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(chemin),
                    width: 74,
                    height: 74,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(width: 74, height: 74, color: Colors.black12, child: const Icon(Icons.broken_image)),
                  ),
                ),
              ),
            if (editable)
              InkWell(
                onTap: () => _ajouter(ref),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: .35)),
                  ),
                  child: Icon(Icons.photo_camera_outlined, color: accent),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}
