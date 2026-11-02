import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../magasins/magasin_repository.dart';
import '../prechargement.dart';
import '../providers.dart';
import 'pilot_accueil_jour_page.dart';
import 'pilot_accueil_page.dart';
import 'prospects_pipeline.dart';

/// Filtres de la liste (comme les pastilles de la maquette).
enum _Filtre { tous, aRelancer, alertes }

/// « auj. », « hier », « il y a 19 j », « jamais » — ancienneté de la dernière visite.
String derniereVisite(int? jours) {
  if (jours == null) return 'jamais';
  if (jours <= 0) return 'auj.';
  if (jours == 1) return 'hier';
  return 'il y a $jours j';
}

/// Magasins de mon périmètre dans ABC Pilot : indicateurs en en-tête, recherche, filtres, liste des magasins avec
/// leur état. Mêmes données que l'onglet Magasins d'ABC Sales (copie locale d'abord, utilisable hors ligne) ;
/// la fiche s'ouvre au toucher.
class PilotMagasinsPage extends ConsumerStatefulWidget {
  const PilotMagasinsPage({super.key});

  @override
  ConsumerState<PilotMagasinsPage> createState() => _PilotMagasinsPageState();
}

class _PilotMagasinsPageState extends ConsumerState<PilotMagasinsPage> {
  String _q = '';
  _Filtre _filtre = _Filtre.tous;

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final role = ref.watch(currentRoleProvider);
    final async = ref.watch(magasinsProvider);
    final tous = async.value?.value ?? const <Magasin>[];
    final prospects = ref.watch(prospectsPipelineProvider).value?.length ?? 0;
    final caMois = ref.watch(pilotAccueilProvider).value?.value.caMois;

    final aRelancer = tous.where((m) => m.enRetard).length;
    final q = _q.trim().toLowerCase();
    final liste = [
      for (final m in tous)
        if (switch (_filtre) {
              _Filtre.tous => true,
              _Filtre.aRelancer => m.enRetard,
              _Filtre.alertes => m.alertes > 0,
            } &&
            (q.isEmpty || m.enseigne.toLowerCase().contains(q) || (m.ville ?? '').toLowerCase().contains(q) || m.codeAs400.toLowerCase().contains(q)))
          m,
    ]..sort((a, b) {
        if (a.enRetard != b.enRetard) return a.enRetard ? -1 : 1;
        return a.enseigne.toLowerCase().compareTo(b.enseigne.toLowerCase());
      });

    Widget pastille(String libelle, _Filtre f) {
      final actif = _filtre == f;
      return ChoiceChip(
        label: Text(libelle),
        selected: actif,
        showCheckmark: false,
        selectedColor: violet,
        labelStyle: TextStyle(color: actif ? Colors.white : null, fontWeight: FontWeight.w700),
        onSelected: (_) => setState(() => _filtre = f),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          final maj = ref.read(miseAJourLocaleProvider);
          await Future.wait([maj.magasins(), maj.pilot(), maj.prospection()]);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 16),
              decoration: BoxDecoration(color: violet, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                EnteteBonjour(sousTitre: '${role?.label ?? ''} · ${tous.length} magasin${tous.length > 1 ? 's' : ''}'),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TuileChiffre(libelle: 'CA du mois', valeur: caMois == null ? '—' : '${(caMois / 1000).round()} k€')),
                  const SizedBox(width: 8),
                  Expanded(child: TuileChiffre(libelle: 'À relancer', valeur: '$aRelancer')),
                  const SizedBox(width: 8),
                  Expanded(child: TuileChiffre(libelle: 'Prospects', valeur: '$prospects')),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un magasin, une ville',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  pastille('Tous · ${tous.length}', _Filtre.tous),
                  pastille('À relancer', _Filtre.aRelancer),
                  pastille('Alertes', _Filtre.alertes),
                ]),
                const SizedBox(height: 12),
                if (async.isLoading && tous.isEmpty)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (liste.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucun magasin ne correspond.', textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted)),
                    ),
                  )
                else
                  for (final m in liste) _Carte(magasin: m),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge d'état du magasin : à relancer (jaune), alerte (rouge pâle), sinon OK (vert).
({String libelle, Color fond, Color texte}) _etat(Magasin m) {
  if (m.enRetard) return (libelle: 'À relancer', fond: const Color(0xFFFCEFC6), texte: const Color(0xFF92400E));
  if (m.alertes > 0 || m.etat == 'alerte') return (libelle: 'Alerte', fond: const Color(0xFFFEE2E2), texte: const Color(0xFF991B1B));
  return (libelle: 'OK', fond: const Color(0xFFDDF5E6), texte: const Color(0xFF166534));
}

class _Carte extends StatelessWidget {
  const _Carte({required this.magasin});

  final Magasin magasin;

  @override
  Widget build(BuildContext context) {
    final e = _etat(magasin);
    final sousTitre = [
      if (magasin.niveauClass != null) 'Classe ${magasin.niveauClass}',
      if (magasin.codeAs400.isNotEmpty) 'Code ${magasin.codeAs400}',
      if (!magasin.actif) 'Inactif',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/pilot/magasins/${magasin.id}', extra: magasin),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  '${magasin.enseigne}${magasin.ville == null || magasin.ville!.isEmpty ? '' : ' – ${magasin.ville}'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: e.fond, borderRadius: BorderRadius.circular(8)),
                child: Text(e.libelle, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: e.texte)),
              ),
            ]),
            if (sousTitre.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sousTitre, style: const TextStyle(fontSize: 12.5, color: StatusColors.muted)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.event_available_outlined, size: 15, color: StatusColors.muted),
              const SizedBox(width: 4),
              Text('Visite : ${derniereVisite(magasin.derniereVisiteJours)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              if (magasin.alertes > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.warning_amber_rounded, size: 15, color: StatusColors.warn),
                const SizedBox(width: 4),
                Text('${magasin.alertes} alerte${magasin.alertes > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
