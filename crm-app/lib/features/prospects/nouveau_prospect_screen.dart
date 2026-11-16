import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'logic/nouveau_prospect.dart';
import 'logic/vue_prospects.dart';
import 'state/nouveau_prospect_state.dart';
import 'state/prospects_state.dart';

/// Formulaire « Nouveau prospect » (écran empilé `nouveau-prospect`). Maquette : nouveauProspect l.1718-1736 et création
/// l.2005-2021.
/// Ouvert par `AppRoutes.nouveauProspect(context)`.
///
/// Sections Identité (enseigne et raison sociale obligatoires, ville, code postal, téléphone, email) et Qualification
/// (secteur, source, classe, étape, probabilité, potentiel). « Créer le prospect » vérifie les champs et affiche les
/// erreurs sous chaque champ ; s'ils sont valides, le prospect entre dans le store « En attente d'envoi », la page
/// Prospects s'ouvre sur « Mes prospects » sans filtre et le toast « Prospect créé… » s'affiche.
class NouveauProspectScreen extends ConsumerWidget {
  const NouveauProspectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(nouveauProspectProvider);
    final f = etat.brouillon;
    final e = etat.erreurs;
    final notifier = ref.read(nouveauProspectProvider.notifier);

    Widget texte(
      String label,
      String valeur,
      BrouillonProspect Function(BrouillonProspect b, String v) maj, {
      String? hint,
      String? erreur,
      TextInputType? clavier,
    }) => ChampTexte(
      label: label,
      valeurInitiale: valeur,
      hint: hint,
      erreur: erreur,
      clavier: clavier,
      onChanged: (v) => notifier.maj((b) => maj(b, v)),
    );

    return PageUnivers(
      entete: TopbarEcran(
        titre: 'Nouveau prospect',
        sous: '* champs obligatoires',
      ),
      paddingCorps: false,
      corps: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitre('Identité'),
            texte(
              'Enseigne *',
              f.enseigne,
              (b, v) => b.copyWith(enseigne: v),
              hint: 'Ex. Super Proxi Lunel',
              erreur: e['enseigne'],
            ),
            texte(
              'Raison sociale *',
              f.raison,
              (b, v) => b.copyWith(raison: v),
              hint: 'Ex. SUPERMARCHÉ DUPONT SAS',
              erreur: e['raison'],
            ),
            Rangee(
              children: [
                texte('Ville', f.ville, (b, v) => b.copyWith(ville: v)),
                texte(
                  'Code postal',
                  f.cp,
                  (b, v) => b.copyWith(cp: v),
                  clavier: TextInputType.number,
                ),
              ],
            ),
            Rangee(
              children: [
                texte(
                  'Téléphone',
                  f.tel,
                  (b, v) => b.copyWith(tel: v),
                  clavier: TextInputType.phone,
                ),
                texte(
                  'Email',
                  f.email,
                  (b, v) => b.copyWith(email: v),
                  clavier: TextInputType.emailAddress,
                  erreur: e['email'],
                ),
              ],
            ),
            const SectionTitre('Qualification'),
            Rangee(
              children: [
                ChampListe<String>(
                  label: 'Secteur',
                  valeur: f.secteur,
                  options: {'': '— aucun —', ...secteursDemo},
                  onChanged: (v) => notifier.maj((b) => b.copyWith(secteur: v)),
                ),
                ChampListe<String>(
                  label: 'Source',
                  valeur: f.source,
                  options: {'': '— non précisée —', ...sourcesProspect},
                  onChanged: (v) => notifier.maj((b) => b.copyWith(source: v)),
                ),
              ],
            ),
            Rangee(
              children: [
                ChampListe<String>(
                  label: 'Classe du client',
                  valeur: f.classe,
                  options: {
                    '': '— non renseignée —',
                    for (final c in classesCreation) c: 'Classe $c',
                  },
                  onChanged: (v) => notifier.maj((b) => b.copyWith(classe: v)),
                ),
                ChampListe<StatutProspect>(
                  label: 'Étape',
                  valeur: f.etape,
                  options: etapesCreation,
                  onChanged: (v) => notifier.maj((b) => b.copyWith(etape: v)),
                ),
              ],
            ),
            Rangee(
              children: [
                texte(
                  'Probabilité (%)',
                  f.proba,
                  (b, v) => b.copyWith(proba: v),
                  clavier: TextInputType.number,
                  erreur: e['proba'],
                ),
                texte(
                  'Potentiel CA/an (€)',
                  f.pot,
                  (b, v) => b.copyWith(pot: v),
                  clavier: const TextInputType.numberWithOptions(decimal: true),
                  erreur: e['pot'],
                ),
              ],
            ),
          ],
        ),
      ),
      bas: BarreBasse(
        enfants: [
          AppBouton('Annuler', onPressed: () => Navigator.of(context).pop()),
          AppBouton(
            '＋ Créer le prospect',
            variante: VarianteBouton.plein,
            onPressed: () => _creer(context, ref),
          ),
        ],
      ),
    );
  }

  /// `np-creer` : valide, crée le prospect et revient sur la page Prospects.
  void _creer(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(nouveauProspectProvider.notifier);
    if (!notifier.valider()) return;
    final store = ref.read(crmProvider.notifier);
    final existants = ref.read(prospectsProvider);
    store.ajouterProspect(
      construireProspect(
        ref.read(nouveauProspectProvider).brouillon,
        id: prochainIdProspect(existants),
        creePar: ref.read(profilActifProvider).nom,
      ),
    );
    ref.read(vueProspectsProvider.notifier).choisir(VueProspects.liste);
    ref.read(filtreGroupeProvider.notifier).definir(null);
    AppToast.show(context, 'Prospect créé. Envoi dès que le réseau le permet.');
    AppRoutes.allerOnglet(context, OngletApp.prospects);
  }
}
