import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/data/fiche_client.dart';
import '../../core/sync/catalogue_provider.dart';
import '../../core/sync/fiche_client_provider.dart';
import '../../core/ui/ui.dart';
import 'logic/actions_magasin.dart';

/// Ouvre la feuille d'un contact du magasin : création (`contact` nul) ou modification et suppression.
Future<void> ouvrirContactMagasin(
  BuildContext context, {
  required String magasinId,
  ContactClient? contact,
}) => showAppSheet<void>(
  context,
  builder: (_) => ContactMagasinSheet(magasinId: magasinId, contact: contact),
);

/// Feuille « Nouveau contact » ou « Modifier le contact » d'un magasin du CRM : prénom, nom, poste, fixe, portable, mail.
///
/// L'écriture part en direct (le serveur gagne) : `POST /clients/:id/contacts`, `PATCH …/contacts/:contactId` ou
/// `DELETE …/contacts/:contactId` (supprimer demande une confirmation). En cas de refus la feuille reste ouverte avec le
/// message de l'API ; sinon la fiche est relue et la feuille se ferme.
class ContactMagasinSheet extends ConsumerStatefulWidget {
  const ContactMagasinSheet({super.key, required this.magasinId, this.contact});

  final String magasinId;

  /// Contact modifié ; nul : nouveau contact.
  final ContactClient? contact;

  @override
  ConsumerState<ContactMagasinSheet> createState() =>
      _ContactMagasinSheetState();
}

class _ContactMagasinSheetState extends ConsumerState<ContactMagasinSheet> {
  late BrouillonContact _b;
  Map<String, String> _erreurs = const {};
  String? _erreurApi;
  bool _envoi = false;
  bool _confirmerSuppression = false;

  bool get _modification => widget.contact?.id != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _b = c == null ? const BrouillonContact() : BrouillonContact.depuis(c);
  }

  Future<void> _enregistrer() async {
    if (_envoi) return;
    final erreurs = validerContact(_b);
    setState(() {
      _erreurs = erreurs;
      _erreurApi = null;
    });
    if (erreurs.isNotEmpty) return;
    final idContact = widget.contact?.id;
    await _appeler(
      _modification ? 'PATCH' : 'POST',
      cheminContact(widget.magasinId, idContact),
      corps: corpsContact(_b, modification: _modification),
      message: _modification ? 'Contact modifié.' : 'Contact ajouté.',
    );
  }

  Future<void> _supprimer() async {
    if (_envoi) return;
    if (!_confirmerSuppression) {
      setState(() => _confirmerSuppression = true);
      return;
    }
    await _appeler(
      'DELETE',
      cheminContact(widget.magasinId, widget.contact!.id),
      message: 'Contact supprimé.',
    );
  }

  Future<void> _appeler(
    String methode,
    String chemin, {
    Object? corps,
    required String message,
  }) async {
    final conteneur = ProviderScope.containerOf(context);
    final api = ref.read(apiEcritureProvider);
    setState(() {
      _envoi = true;
      _erreurApi = null;
    });
    try {
      await api.envoyer(methode, chemin, corps: corps);
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreurApi = messageErreurMagasin(e);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreurApi = const ErreurApi(TypeErreurApi.inattendue).message;
      });
      return;
    }
    conteneur.invalidate(ficheClientProvider(widget.magasinId));
    if (!mounted) return;
    AppToast.show(context, message);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ChampTexte champ(
      String cle,
      String label,
      String valeur,
      BrouillonContact Function(String v) maj, {
      TextInputType? clavier,
    }) => ChampTexte(
      label: label,
      valeurInitiale: valeur,
      clavier: clavier,
      erreur: _erreurs[cle],
      onChanged: (v) => _b = maj(v),
    );
    final b = _b;
    return FeuilleBase(
      titre: _modification ? 'Modifier le contact' : 'Nouveau contact',
      children: [
        if (_erreurApi != null) MessageErreur(_erreurApi!),
        champ('prenom', 'Prénom', b.prenom, (v) => _b.copyWith(prenom: v)),
        champ('nom', 'Nom *', b.nom, (v) => _b.copyWith(nom: v)),
        champ('poste', 'Poste', b.poste, (v) => _b.copyWith(poste: v)),
        champ(
          'fixe',
          'Téléphone fixe',
          b.fixe,
          (v) => _b.copyWith(fixe: v),
          clavier: TextInputType.phone,
        ),
        champ(
          'portable',
          'Portable',
          b.portable,
          (v) => _b.copyWith(portable: v),
          clavier: TextInputType.phone,
        ),
        champ(
          'mail',
          'Mail',
          b.mail,
          (v) => _b.copyWith(mail: v),
          clavier: TextInputType.emailAddress,
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
              onPressed: _envoi ? null : () => unawaited(_enregistrer()),
            ),
          ],
        ),
        if (_modification)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppBouton(
              _confirmerSuppression
                  ? 'Confirmer la suppression'
                  : 'Supprimer le contact',
              petit: true,
              variante: VarianteBouton.danger,
              onPressed: _envoi ? null : () => unawaited(_supprimer()),
            ),
          ),
      ],
    );
  }
}
