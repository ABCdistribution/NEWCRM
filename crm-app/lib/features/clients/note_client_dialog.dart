import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';

/// Ouvre le dialogue « Nouvelle note ». Maquette : modale `note` l.1836-1838 et action `note-ok` l.2032.
/// Appelée par `AppRoutes.noteClient(context, magasinId)`.
Future<void> ouvrirNoteClient(BuildContext context, String magasinId) =>
    showAppDialog<void>(
      context,
      builder: (_) => NoteClientDialog(magasinId: magasinId),
    );

/// Dialogue « Nouvelle note » : zone de texte « Votre remarque », Annuler / Enregistrer, toast « Note enregistrée. Envoi dès que le réseau le permet. ».
///
/// Comme dans la maquette, une note vide n'est pas enregistrée (le dialogue reste ouvert, la zone est vidée) et la
/// note d'un client n'ajoute rien à sa fiche : seul le toast confirme (l'ajout à la timeline ne concerne que les prospects).
class NoteClientDialog extends StatefulWidget {
  const NoteClientDialog({super.key, required this.magasinId});

  /// Client concerné.
  final String magasinId;

  @override
  State<NoteClientDialog> createState() => _NoteClientDialogState();
}

class _NoteClientDialogState extends State<NoteClientDialog> {
  final TextEditingController _texte = TextEditingController();

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  void _enregistrer() {
    if (_texte.text.trim().isEmpty) {
      _texte.clear();
      return;
    }
    AppToast.show(
      context,
      'Note enregistrée. Envoi dès que le réseau le permet.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final cadre = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordureChamp),
    );
    return DialogueBase(
      titre: 'Nouvelle note',
      children: [
        // `.champ textarea` : 72 px minimum, marge basse de 12, mise au point automatique.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _texte,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: AppText.champ,
            decoration: InputDecoration(
              hintText: 'Votre remarque',
              hintStyle: AppText.t(14, c: AppColors.muted),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              constraints: const BoxConstraints(minHeight: 72),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: cadre,
              enabledBorder: cadre,
              focusedBorder: cadre.copyWith(
                borderSide: BorderSide(color: u.acc),
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
              onPressed: _enregistrer,
            ),
          ],
        ),
      ],
    );
  }
}
