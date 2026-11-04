import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/role.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../prechargement.dart';
import '../shell/app_shell.dart';
import '../shell/selecteur_espace.dart';
import 'pilot_accueil_page.dart';
import 'pilot_planning_page.dart';
import 'pilot_prospect_fiche_page.dart' show ouvrirFicheDeLigne;
import 'prospects_pipeline.dart';
import 'tournee_etapes.dart';

const _joursCourts = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Initiales (deux premiers mots) d'un nom affiché.
String initialesDe(String nom) =>
    nom.split(' ').where((s) => s.isNotEmpty && RegExp('[A-Za-zÀ-ÿ]').hasMatch(s[0])).take(2).map((s) => s[0].toUpperCase()).join();

/// Prénom pour « Bonjour … » : le premier mot du nom affiché (l'AD range « Prénom NOM »).
String prenomDe(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+'));
  final prenom = mots.firstWhere((m) => m.isNotEmpty, orElse: () => '');
  return prenom.isEmpty ? '' : '${prenom[0].toUpperCase()}${prenom.substring(1).toLowerCase()}';
}

/// En-tête commun des accueils Pilot : avatar, « Bonjour prénom », sous-titre et cloche.
class EnteteBonjour extends ConsumerWidget {
  const EnteteBonjour({super.key, required this.sousTitre});

  final String sousTitre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nom = ref.watch(sessionProvider).value?.user.displayName ?? '';
    return Row(children: [
      InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/profil'),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
          child: Text(initialesDe(nom), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bonjour ${prenomDe(nom)}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          Text(sousTitre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
        child: const EnteteActions(),
      ),
    ]);
  }
}

/// Tuile de chiffre de l'en-tête violet (valeur et libellé).
class TuileChiffre extends StatelessWidget {
  const TuileChiffre({super.key, required this.libelle, required this.valeur});

  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(libelle, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600))),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(valeur, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800))),
        ]),
      );
}

/// Accueil d'ABC Pilot : ma tournée du jour (étapes de MA tournée, les mêmes que sur le web), l'étape suivante en
/// évidence, et les raccourcis « + Prospect » et « + RDV ».
class PilotAccueilJourPage extends ConsumerWidget {
  const PilotAccueilJourPage({super.key});

  void _message(BuildContext context, String texte) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texte)));

  /// Ouvre l'application de cartes sur le magasin ou le prospect : coordonnées si on les a, sinon l'adresse postale.
  Future<void> _ouvrirItineraire(BuildContext context, EtapeTournee e) async {
    if (!e.aUneAdresse) {
      _message(context, 'Aucune adresse renseignée pour ${e.type == 'PROSPECT' ? 'ce prospect' : 'ce magasin'}.');
      return;
    }
    final nom = Uri.encodeComponent(e.titre);
    final uri = e.latitude != null && e.longitude != null
        ? Uri.parse('geo:${e.latitude},${e.longitude}?q=${e.latitude},${e.longitude}($nom)')
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(e.adresse!)}');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
        _message(context, 'Aucune application de cartes disponible.');
      }
    } on Object {
      if (context.mounted) _message(context, 'Aucune application de cartes disponible.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violet = SpacePalette.pilot.accent;
    final role = ref.watch(currentRoleProvider);
    final auj = DateTime.now();
    final jour = DateTime(auj.year, auj.month, auj.day);
    final lundi = lundiDe(jour);

    bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final etapes = [
      ...(ref.watch(etapesSemaineProvider(lundi)).value ?? const <EtapeTournee>[]),
      for (final e in ref.watch(etapesEnAttenteProvider).value ?? const <EtapeTournee>[])
        if (memeJour(e.jour, jour)) e,
    ].where((e) => memeJour(e.jour, jour)).toList()
      ..sort((a, b) => (a.heure ?? '99:99').compareTo(b.heure ?? '99:99'));
    final faites = etapes.where((e) => e.fait).length;
    final prochaine = etapes.where((e) => !e.fait).firstOrNull;
    ref.listen(etapesEnAttenteProvider, (_, _) => ref.read(miseAJourLocaleProvider).etapes(lundi));

    final prospects = ref.watch(prospectsPipelineProvider).value ?? const <ProspectPipeline>[];
    final enNego = prospects.where((p) => p.groupe == GroupeProspect.enNego).length;
    final peutCreer = role != Role.direction;
    // Rapport de la semaine validé : plus aucune ligne ne s'ajoute.
    final semaineVerrouillee = ref.watch(etatSemaineProvider(lundi)).value?.verrouillee ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          final maj = ref.read(miseAJourLocaleProvider);
          await Future.wait([maj.etapes(lundi), maj.prospection()]);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 16),
              decoration: BoxDecoration(color: violet, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                EnteteBonjour(sousTitre: '${role?.label ?? ''} · ${_joursCourts[jour.weekday - 1]} ${jour.day} ${_moisCourts[jour.month - 1]}'),
                const SizedBox(height: 14),
                // Bascule vers ABC Sales (réservée à l'encadrement, masquée pour les autres rôles).
                const SelecteurEspace(space: Space.pilot),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TuileChiffre(libelle: 'RDV du jour', valeur: '$faites/${etapes.length}')),
                  const SizedBox(width: 8),
                  Expanded(child: TuileChiffre(libelle: 'Prospects', valeur: '${prospects.length}')),
                  const SizedBox(width: 8),
                  Expanded(child: TuileChiffre(libelle: 'En négo', valeur: '$enNego')),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('Ma tournée du jour', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                  InkWell(
                    onTap: () => ref.read(pilotTabProvider.notifier).select(3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Voir la semaine', style: TextStyle(color: violet, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                if (etapes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucune étape aujourd\'hui. Ajoutez un RDV ci-dessous.', textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted)),
                    ),
                  )
                else
                  for (final e in etapes)
                    if (identical(e, prochaine))
                      _EtapeProchaine(
                        etape: e,
                        onTap: () => ouvrirFicheDeLigne(context, e),
                        onItineraire: () => _ouvrirItineraire(context, e),
                      )
                    else
                      _EtapeLigne(etape: e, onTap: () => ouvrirFicheDeLigne(context, e)),
                const SizedBox(height: 8),
                Row(children: [
                  if (peutCreer) ...[
                    Expanded(child: _Raccourci(icone: Icons.add, libelle: 'Prospect', onTap: () => context.push('/prospects/nouveau'))),
                    const SizedBox(width: 10),
                  ],
                  if (!semaineVerrouillee)
                    Expanded(child: _Raccourci(icone: Icons.add, libelle: 'RDV', onTap: () => context.push('/rdv/nouveau?date=${jourIso(jour)}'))),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Hyper Plaine – Noisy ».
String _titre(EtapeTournee e) => '${e.titre}${e.ville == null ? '' : ' – ${e.ville}'}';

String _nature(EtapeTournee e) => switch (e.type) {
      'PROSPECT' => 'Prospect',
      'CLIENT' => 'Client',
      'LIBRE' => 'Libre',
      _ => 'ADM',
    };

class _EtapeLigne extends StatelessWidget {
  const _EtapeLigne({required this.etape, required this.onTap});

  final EtapeTournee etape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fait = etape.fait;
    final details = [
      if (etape.heure != null) etape.heure!,
      _nature(etape),
      if ((etape.note ?? '').isNotEmpty) etape.note!,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: fait ? const Color(0xFFEAF8EF) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: fait ? const Color(0xFFCDEFD9) : const Color(0xFFF0F1F6), shape: BoxShape.circle),
            child: Icon(fait ? Icons.check : Icons.schedule, size: 19, color: fait ? StatusColors.ok : StatusColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_titre(etape), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(details.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: StatusColors.muted)),
              if (etape.enAttente)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('En attente d\'envoi', style: TextStyle(fontSize: 12, color: StatusColors.warn, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: fait ? const Color(0xFFCDEFD9) : const Color(0xFFEDEFF3), borderRadius: BorderRadius.circular(8)),
            child: Text(fait ? 'Fait' : 'À venir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fait ? const Color(0xFF166534) : const Color(0xFF374151))),
          ),
        ]),
        ),
      ),
    );
  }
}

/// L'étape suivante, mise en évidence : détail et « Itinéraire ».
class _EtapeProchaine extends StatelessWidget {
  const _EtapeProchaine({required this.etape, required this.onTap, required this.onItineraire});

  final EtapeTournee etape;
  final VoidCallback onTap;
  final VoidCallback onItineraire;

  @override
  Widget build(BuildContext context) {
    final p = SpacePalette.pilot;
    final details = [
      if (etape.heure != null) etape.heure!,
      _nature(etape),
      if (etape.accompagnement) 'Accompagnement' else if (etape.visiteSimple) 'Visite simple',
      if (etape.rdv) 'RDV',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accent, width: 1.6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.accent.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(Icons.place_outlined, size: 19, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_titre(etape), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(details.join(' · '), style: const TextStyle(fontSize: 12.5, color: StatusColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: p.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
            child: Text('Prochain', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.accent)),
          ),
        ]),
        if ((etape.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F8), borderRadius: BorderRadius.circular(10)),
            child: Text(etape.note!, style: const TextStyle(fontSize: 13)),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onItineraire, child: const Text('Itinéraire')),
      ]),
        ),
      ),
    );
  }
}

class _Raccourci extends StatelessWidget {
  const _Raccourci({required this.icone, required this.libelle, required this.onTap});

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(libelle),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      );
}
