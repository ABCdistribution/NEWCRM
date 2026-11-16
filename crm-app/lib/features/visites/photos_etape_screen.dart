import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/sync/photos_visite_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'state/actions_visite.dart';

/// Photos d'une étape de visite : miniatures déjà prises, bouton « Prendre une photo » (appareil photo du téléphone),
/// suppression d'une photo. Ouverte par `AppRoutes.photosEtapeVisite`.
class PhotosEtapeScreen extends ConsumerStatefulWidget {
  const PhotosEtapeScreen({
    super.key,
    required this.visiteId,
    required this.etape,
  });

  final String visiteId;
  final EtapeDph etape;

  @override
  ConsumerState<PhotosEtapeScreen> createState() => _PhotosEtapeScreenState();
}

class _PhotosEtapeScreenState extends ConsumerState<PhotosEtapeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _occupe = false;

  ActionsVisite get _actions =>
      ActionsVisite(ref.read(crmProvider.notifier), widget.visiteId);

  @override
  void initState() {
    super.initState();
    _recupererPerdue();
  }

  /// Android peut fermer l'application pendant que l'appareil photo est ouvert : on récupère alors la photo prise.
  Future<void> _recupererPerdue() async {
    try {
      final r = await _picker.retrieveLostData();
      final fichier = r.file;
      if (r.isEmpty || fichier == null) return;
      await _enregistrer(await fichier.readAsBytes());
    } catch (_) {}
  }

  Future<void> _enregistrer(List<int> octets) async {
    final ok = await ref
        .read(photosVisiteProvider(widget.visiteId).notifier)
        .ajouter(widget.etape.cle, octets);
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
    try {
      final fichier = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (fichier != null) await _enregistrer(await fichier.readAsBytes());
    } catch (_) {
      if (mounted) {
        AppToast.show(context, "L'appareil photo n'est pas disponible.");
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _supprimer(int id) async {
    await ref
        .read(photosVisiteProvider(widget.visiteId).notifier)
        .supprimer(id);
    if (mounted) _actions.retirerPhoto(widget.etape);
  }

  @override
  Widget build(BuildContext context) {
    final toutes = ref.watch(photosVisiteProvider(widget.visiteId));
    final photos = [
      for (final p in toutes)
        if (p.etape == widget.etape.cle) p,
    ];
    final magasin = ref
        .watch(visiteParIdProvider(widget.visiteId))
        ?.magasinId;
    final nom = magasin == null
        ? null
        : ref.watch(magasinParIdProvider(magasin))?.nom;
    return PageUnivers(
      entete: TopbarEcran(
        titre: widget.etape.libelle,
        sous: nom,
        tailleTitre: 16,
      ),
      enfants: [
        if (photos.isEmpty)
          const Vide('Aucune photo pour cette étape.')
        else
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final p in photos)
                _Miniature(
                  octets: p.octets,
                  onSupprimer: () => _supprimer(p.id),
                ),
            ],
          ),
      ],
      bas: BarreBasse(
        blanc: true,
        enfants: [
          AppBouton(
            _occupe ? 'Ouverture…' : '📷 Prendre une photo',
            variante: VarianteBouton.plein,
            onPressed: _prendre,
          ),
          AppBouton(
            photos.isEmpty ? 'Retour' : '✓ Terminé',
            variante: VarianteBouton.clair,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
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
