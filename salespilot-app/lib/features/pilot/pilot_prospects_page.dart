import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/role.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../prechargement.dart';
import 'prospects_pipeline.dart';
import 'tournee_etapes.dart';

const _moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « RDV · auj. 09:00 », « Visite · 30 oct. » : prochaine étape planifiée du prospect dans MA tournée.
String prochaineAction(EtapeTournee e, [DateTime? maintenant]) {
  final n = maintenant ?? DateTime.now();
  final ecart = e.jour.difference(DateTime(n.year, n.month, n.day)).inDays;
  final jour = ecart == 0 ? 'auj.' : (ecart == 1 ? 'demain' : '${e.jour.day} ${_moisCourts[e.jour.month - 1]}');
  final nature = e.rdv ? 'RDV' : (e.accompagnement ? 'Accomp.' : 'Visite');
  return '$nature · $jour${e.heure == null ? '' : ' ${e.heure}'}';
}

/// Mes prospects (onglet « Prospects » d'ABC Pilot) : compteurs du pipeline, potentiel total et liste triée par
/// potentiel. Les quatre compteurs filtrent la liste (un second appui retire le filtre).
class PilotProspectsPage extends ConsumerStatefulWidget {
  const PilotProspectsPage({super.key});

  @override
  ConsumerState<PilotProspectsPage> createState() => _PilotProspectsPageState();
}

class _PilotProspectsPageState extends ConsumerState<PilotProspectsPage> {
  GroupeProspect? _filtre;

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final async = ref.watch(prospectsPipelineProvider);
    // Les prospects créés sur le téléphone et pas encore envoyés apparaissent tout de suite dans la liste.
    final tous = [
      ...(async.value ?? const <ProspectPipeline>[]),
      ...(ref.watch(prospectsEnAttenteProvider).value ?? const <ProspectPipeline>[]),
    ];
    final prochaines = ref.watch(prochainesEtapesProvider).value ?? const <String, EtapeTournee>{};
    // Une étape ou un prospect part (ou est ajouté) : la liste et les « prochaines actions » suivent le serveur.
    ref.listen(etapesEnAttenteProvider, (_, _) => ref.read(miseAJourLocaleProvider).prochaines());
    ref.listen(prospectsEnAttenteProvider, (_, _) => ref.read(miseAJourLocaleProvider).prospection());
    // La création est refusée par l'API à la Direction (chef de secteur, directeur régional et admin seulement).
    final peutCreer = ref.watch(currentRoleProvider) != Role.direction;

    final liste = [for (final p in tous) if (_filtre == null || p.groupe == _filtre) p]..sort(parPotentiel);
    final potentielTotal = tous.fold<double>(0, (somme, p) => somme + (p.potentiel ?? 0));
    int nb(GroupeProspect g) => tous.where((p) => p.groupe == g).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(children: [
        RefreshIndicator(
          onRefresh: () async {
            await ref.read(miseAJourLocaleProvider).prospection();
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 16),
                decoration: BoxDecoration(color: violet, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Mes prospects', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${tous.length} point${tous.length > 1 ? 's' : ''} de vente · potentiel ${potentielCourt(potentielTotal)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (final g in GroupeProspect.values) ...[
                      if (g != GroupeProspect.aContacter) const SizedBox(width: 8),
                      Expanded(
                        child: _Compteur(
                          valeur: nb(g),
                          libelle: g.libelle,
                          actif: _filtre == g,
                          onTap: () => setState(() => _filtre = _filtre == g ? null : g),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Expanded(child: Text('Pipeline', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    const Text('Trié par potentiel', style: TextStyle(color: StatusColors.muted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 12),
                  if (async.isLoading && tous.isEmpty)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  else if (liste.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tous.isEmpty ? 'Aucun prospect pour le moment.' : 'Aucun prospect dans cette colonne.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: StatusColors.muted),
                        ),
                      ),
                    )
                  else
                    for (final p in liste) _Carte(prospect: p, action: prochaines[p.id]),
                ]),
              ),
            ],
          ),
        ),
        if (peutCreer)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => context.push('/prospects/nouveau'),
              backgroundColor: violet,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau prospect', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.libelle, required this.actif, required this.onTap});

  final int valeur;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: actif ? Colors.white : Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text('$valeur', style: TextStyle(color: actif ? violet : Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(libelle, style: TextStyle(color: actif ? violet : Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

/// Pastille d'étape : couleurs de la maquette.
({Color fond, Color texte}) _couleurs(GroupeProspect g) => switch (g) {
      GroupeProspect.enNego => (fond: const Color(0xFFFCEFC6), texte: const Color(0xFF92400E)),
      GroupeProspect.rdvPris => (fond: const Color(0xFFDFE8FF), texte: const Color(0xFF1E3A8A)),
      GroupeProspect.aContacter => (fond: const Color(0xFFEDEFF3), texte: const Color(0xFF374151)),
      GroupeProspect.reference => (fond: const Color(0xFFDDF5E6), texte: const Color(0xFF166534)),
    };

class _Carte extends StatelessWidget {
  const _Carte({required this.prospect, required this.action});

  final ProspectPipeline prospect;

  /// Prochaine étape planifiée pour ce prospect, s'il y en a une.
  final EtapeTournee? action;

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final c = _couleurs(prospect.groupe);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(
                '${prospect.enseigne}${prospect.ville == null ? '' : ' – ${prospect.ville}'}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: c.fond, borderRadius: BorderRadius.circular(8)),
              child: Text(prospect.groupe.libelle, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.texte)),
            ),
          ]),
          if (prospect.niveauClass != null) ...[
            const SizedBox(height: 2),
            Text('Classe ${prospect.niveauClass}', style: const TextStyle(fontSize: 12.5, color: StatusColors.muted)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Potentiel ', style: TextStyle(fontSize: 13, color: StatusColors.muted)),
                TextSpan(text: potentielCourt(prospect.potentiel), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ])),
            ),
            if (action != null) ...[
              Icon(Icons.event_outlined, size: 15, color: violet),
              const SizedBox(width: 4),
              Text(prochaineAction(action!), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: violet)),
            ],
          ]),
          if (prospect.enAttente) ...[
            const SizedBox(height: 6),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_send_outlined, size: 14, color: StatusColors.warn),
              SizedBox(width: 4),
              Text('En attente d\'envoi', style: TextStyle(fontSize: 12, color: StatusColors.warn, fontWeight: FontWeight.w700)),
            ]),
          ],
        ]),
      ),
    );
  }
}
