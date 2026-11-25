import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/envoi/corps_activite.dart';
import '../../core/envoi/corps_visite.dart';
import '../../core/envoi/envoi_provider.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';

/// Ouvre le dialogue « Nouvelle note ». Maquette : modale `note` l.1836-1838 et action `note-ok` l.2032.
/// Appelée par `AppRoutes.noteProspect(context, prospectId)`.
Future<void> ouvrirNoteProspect(BuildContext context, String prospectId) =>
    showAppDialog<void>(
      context,
      builder: (_) => NoteProspectDialog(prospectId: prospectId),
    );

/// Dialogue « Nouvelle note » : zone de texte, Annuler / Enregistrer. Une note vide n'est pas enregistrée et le
/// dialogue reste ouvert ; sinon le dialogue se ferme et « Note enregistrée. Envoi dès que le réseau le permet. »
/// s'affiche. Connecté, la note part au CRM par la file d'envoi (`POST /prospects/:id/notes`, idempotent par `idApk`) et
/// la fiche est relue une fois partie ; en démonstration, elle s'ajoute en tête de la timeline locale du prospect.
class NoteProspectDialog extends ConsumerStatefulWidget {
  const NoteProspectDialog({super.key, required this.prospectId});

  /// Prospect concerné.
  final String prospectId;

  @override
  ConsumerState<NoteProspectDialog> createState() => _NoteProspectDialogState();
}

class _NoteProspectDialogState extends ConsumerState<NoteProspectDialog> {
  final TextEditingController _texte = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final note = _texte.text.trim();
    if (note.isEmpty || _enCours) return;
    _enCours = true;
    var enfilee = false;
    if (DemoTemps.reel && estUuid(widget.prospectId)) {
      enfilee = await ref
          .read(envoiProvider.notifier)
          .enfilerActivite(
            requeteNote(CibleActivite.prospect, widget.prospectId, note),
          );
    }
    if (!mounted) return;
    if (!enfilee) {
      ref
          .read(crmProvider.notifier)
          .ajouterEvenementProspect(
            widget.prospectId,
            EvenementProspect(
              icone: IconeEvenement.doc,
              couleur: 0xFF6B7280,
              titre: 'Note',
              date: 'auj.',
              detail: note,
            ),
          );
    }
    AppToast.show(
      context,
      'Note enregistrée. Envoi dès que le réseau le permet.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cadre = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordureChamp),
    );
    return DialogueBase(
      titre: 'Nouvelle note',
      children: [
        // `.champ textarea` : 72 px de haut, défile au-delà.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 72,
            child: TextField(
              controller: _texte,
              autofocus: true,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              inputFormatters: [LengthLimitingTextInputFormatter(maxRemarque)],
              style: AppText.champ,
              decoration: InputDecoration(
                hintText: 'Votre remarque',
                hintStyle: AppText.t(14, c: AppColors.muted),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                border: cadre,
                enabledBorder: cadre,
                focusedBorder: cadre.copyWith(
                  borderSide: BorderSide(color: context.univers.acc),
                ),
              ),
            ),
          ),
        ),
        Rangee(
          children: [
            AppBouton(
              'Annuler',
              petit: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppBouton(
              'Enregistrer',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => unawaited(_enregistrer()),
            ),
          ],
        ),
      ],
    );
  }
}
