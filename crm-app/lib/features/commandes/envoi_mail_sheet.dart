import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/fiche_client_provider.dart';
import '../../core/ui/ui.dart';
import 'commande_actions.dart';
import 'logic/attente_crm.dart';
import 'state/commande_provider.dart';

/// Ouvre la feuille « Envoyer par mail » de la commande en cours.
Future<void> ouvrirEnvoiMail(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const EnvoiMailSheet());

/// Feuille d'envoi de la commande par mail au client : adresse pré-remplie (celle déjà utilisée pour cette commande,
/// sinon celle de la fiche client), contrôle du format, envoi. La commande reste en attente.
class EnvoiMailSheet extends ConsumerStatefulWidget {
  const EnvoiMailSheet({super.key});

  @override
  ConsumerState<EnvoiMailSheet> createState() => _EnvoiMailSheetState();
}

class _EnvoiMailSheetState extends ConsumerState<EnvoiMailSheet> {
  final TextEditingController _email = TextEditingController();

  /// Le promoteur a tapé dans le champ : l'adresse de la fiche client n'écrase plus sa saisie.
  bool _saisie = false;
  String? _erreur;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final cmd = ref.read(commandeEnCoursProvider);
    final fiche = cmd?.magasinId == null
        ? null
        : ref.read(ficheClientProvider(cmd!.magasinId!)).value?.mail;
    _email.text =
        cmd?.crm?.emailValidation ?? cmd?.crm?.clientEmail ?? fiche ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final adresse = _email.text.trim();
    if (!emailValide(adresse)) {
      setState(() => _erreur = 'Adresse e-mail invalide.');
      return;
    }
    setState(() {
      _erreur = null;
      _envoi = true;
    });
    final conteneur = ProviderScope.containerOf(context);
    final erreur = await envoyerCommandeParMail(conteneur, adresse);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
    AppToast.show(
      context,
      'Commande envoyée à $adresse. Elle reste en attente.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(commandeEnCoursProvider.select((c) => c?.magasinId));
    if (id != null) {
      // La fiche client arrive après l'ouverture : elle ne remplace ni une adresse déjà connue ni une saisie.
      ref.listen(ficheClientProvider(id), (_, suivant) {
        final mail = suivant.value?.mail;
        if (!_saisie && _email.text.isEmpty && mail != null) {
          _email.text = mail;
        }
      });
    }
    return FeuilleBase(
      titre: 'Envoyer par mail',
      children: [
        ChampTexte(
          label: 'Adresse e-mail du client',
          controller: _email,
          clavier: TextInputType.emailAddress,
          erreur: _erreur,
          onChanged: (_) => _saisie = true,
          hint: 'client@exemple.fr',
        ),
        Rangee(
          children: [
            AppBouton(
              'Annuler',
              onPressed: _envoi ? null : () => Navigator.of(context).pop(),
            ),
            AppBouton(
              _envoi ? 'Envoi…' : 'Envoyer',
              variante: VarianteBouton.plein,
              onPressed: _envoi ? null : _envoyer,
            ),
          ],
        ),
      ],
    );
  }
}
