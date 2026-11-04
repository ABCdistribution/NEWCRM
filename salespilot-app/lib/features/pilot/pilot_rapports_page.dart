import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'pilot_accueil_jour_page.dart' show TuileChiffre;
import 'pilot_accueil_page.dart' show pilotTabProvider;
import 'tournee_etapes.dart';

const _moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _moisLongs = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _joursCourts = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// Une semaine de MES rapports, telle que `GET /tournees/historique` la renvoie.
class RapportSemaine {
  const RapportSemaine({
    required this.lundi,
    required this.numero,
    required this.statut,
    required this.valideAt,
    required this.nbPrevues,
    required this.nbLignes,
    required this.visites,
    required this.rdv,
    required this.pourcentPrevu,
  });

  final DateTime lundi;
  final int numero;
  final String statut; // PREVISION_A_SAISIR | PREVISION_ENREGISTREE | EN_COURS | VALIDE | VALIDE_AUTO
  final DateTime? valideAt;
  final int? nbPrevues;
  final int nbLignes;
  final int visites;
  final int rdv;
  final int? pourcentPrevu;

  bool get validee => statut == 'VALIDE' || statut == 'VALIDE_AUTO';
  bool get auto => statut == 'VALIDE_AUTO';

  DateTime get vendredi => lundi.add(const Duration(days: 4));

  factory RapportSemaine.fromJson(Map<String, dynamic> j) {
    final l = DateTime.parse(j['semaine'] as String);
    final v = j['valideAt'] as String?;
    return RapportSemaine(
      lundi: DateTime(l.year, l.month, l.day),
      numero: (j['numero'] as num?)?.toInt() ?? 0,
      statut: j['statut'] as String? ?? 'EN_COURS',
      valideAt: v == null ? null : DateTime.parse(v).toLocal(),
      nbPrevues: (j['nbPrevues'] as num?)?.toInt(),
      nbLignes: (j['nbLignes'] as num?)?.toInt() ?? 0,
      visites: (j['visites'] as num?)?.toInt() ?? 0,
      rdv: (j['rdv'] as num?)?.toInt() ?? 0,
      pourcentPrevu: (j['pourcentPrevu'] as num?)?.toInt(),
    );
  }
}

class HistoriqueRapports {
  const HistoriqueRapports({required this.mois, required this.visitesMois, required this.pourcentMois, required this.references, required this.semaines});

  final int mois; // 1-12
  final int visitesMois;
  final int? pourcentMois;
  final int references;
  final List<RapportSemaine> semaines;

  static const vide = HistoriqueRapports(mois: 0, visitesMois: 0, pourcentMois: null, references: 0, semaines: []);

  factory HistoriqueRapports.fromJson(Map<String, dynamic> j) => HistoriqueRapports(
    mois: int.tryParse(((j['mois'] as String?) ?? '').split('-').last) ?? 0,
    visitesMois: (j['visitesMois'] as num?)?.toInt() ?? 0,
    pourcentMois: (j['pourcentPrevuMois'] as num?)?.toInt(),
    references: (j['references'] as num?)?.toInt() ?? 0,
    semaines: [
      for (final s in ((j['semaines'] as List?) ?? const []).cast<Map<String, dynamic>>()) RapportSemaine.fromJson(s),
    ],
  );
}

const _cleHistorique = 'rapports-historique';

/// Réseau d'abord (les chiffres changent à chaque validation), copie locale en secours hors ligne.
final historiqueRapportsProvider = FutureProvider.autoDispose<HistoriqueRapports>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return HistoriqueRapports.vide;
  final cache = ref.read(cacheRepositoryProvider);
  try {
    final res = await ref.read(dioProvider).get<Map<String, dynamic>>('/tournees/historique');
    final brut = Map<String, dynamic>.from(res.data ?? const {});
    await cache.put(userId, _cleHistorique, brut);
    return HistoriqueRapports.fromJson(brut);
  } on Object {
    final copie = await cache.get(userId, _cleHistorique);
    if (copie != null) return HistoriqueRapports.fromJson(Map<String, dynamic>.from(copie.value as Map));
    rethrow;
  }
});

/// Onglet « Rapports » d'ABC Pilot : un rapport par semaine, transmis au directeur.
class PilotRapportsPage extends ConsumerWidget {
  const PilotRapportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violet = SpacePalette.pilot.accent;
    final async = ref.watch(historiqueRapportsProvider);
    final h = async.value ?? HistoriqueRapports.vide;
    final courante = h.semaines.where((s) => !s.validee).firstOrNull;
    final precedents = h.semaines.where((s) => s.validee).toList();
    final mois = h.mois == 0 ? '' : _moisCourts[h.mois - 1].replaceAll('.', '');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(historiqueRapportsProvider);
          await ref.read(historiqueRapportsProvider.future).catchError((_) => HistoriqueRapports.vide);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 18),
              decoration: BoxDecoration(color: violet, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Mes rapports', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('Un rapport par semaine · transmis au directeur', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TuileChiffre(libelle: mois.isEmpty ? 'Visites' : 'Visites $mois.', valeur: '${h.visitesMois}')),
                  const SizedBox(width: 8),
                  Expanded(child: TuileChiffre(libelle: 'Réalisé / prévu', valeur: h.pourcentMois == null ? '—' : '${h.pourcentMois} %')),
                  const SizedBox(width: 8),
                  Expanded(child: TuileChiffre(libelle: 'Référencés', valeur: '${h.references}')),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (async.isLoading && async.value == null)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (async.hasError && async.value == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Rapports indisponibles : connectez-vous au réseau puis tirez pour actualiser.', textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted)),
                    ),
                  )
                else ...[
                  if (courante != null) _CarteEnCours(semaine: courante),
                  if (courante != null) const SizedBox(height: 22),
                  Row(children: [
                    const Expanded(child: Text('Rapports précédents', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    Text('${DateTime.now().year}', style: const TextStyle(color: StatusColors.muted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 12),
                  if (precedents.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Aucun rapport validé pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted)),
                      ),
                    )
                  else
                    for (final s in precedents) _CarteRapport(semaine: s),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

String _periode(DateTime lundi) {
  final v = lundi.add(const Duration(days: 4));
  final mois = _moisLongs[v.month - 1];
  return lundi.month == v.month
      ? '${lundi.day} – ${v.day} $mois'
      : '${lundi.day} ${_moisLongs[lundi.month - 1]} – ${v.day} $mois';
}

String _horodatage(DateTime d) =>
    '${_joursCourts[d.weekday - 1]} ${d.day} ${_moisCourts[d.month - 1]} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Semaine en cours : accès direct à l'onglet Tournée, où se saisit et se valide le rapport.
class _CarteEnCours extends ConsumerWidget {
  const _CarteEnCours({required this.semaine});

  final RapportSemaine semaine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aVenir = semaine.statut == 'PREVISION_A_SAISIR' || semaine.statut == 'PREVISION_ENREGISTREE';
    final lignes = semaine.nbPrevues ?? semaine.nbLignes;
    final detail = aVenir
        ? (semaine.nbPrevues == null ? 'Prévision à saisir' : '$lignes ligne${lignes > 1 ? 's' : ''} prévue${lignes > 1 ? 's' : ''} · modifiable jusqu\'au lundi soir')
        : '$lignes ligne${lignes > 1 ? 's' : ''} ${semaine.nbPrevues == null ? 'saisie${lignes > 1 ? 's' : ''}' : 'prévue${lignes > 1 ? 's' : ''}'} · à valider vendredi';
    final badge = aVenir ? 'Prévision' : 'À valider';
    return Material(
      color: const Color(0xFFFEF9E7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFF3E3A1))),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => ref.read(pilotTabProvider.notifier).select(3),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFFCE9A8), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.description_outlined, color: Color(0xFFB45309)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Semaine ${semaine.numero} · en cours', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: StatusColors.muted, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFFCE9A8), borderRadius: BorderRadius.circular(10)),
              child: Text(badge, style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Un rapport validé : chiffres de la semaine, puis horodatage de la validation.
class _CarteRapport extends ConsumerWidget {
  const _CarteRapport({required this.semaine});

  final RapportSemaine semaine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = semaine;
    final valide = s.valideAt;
    final pied = valide == null
        ? ''
        : s.auto
            ? 'Validé automatiquement le ${_horodatage(valide)}'
            : 'Validé le ${_horodatage(valide)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _ouvrirDetail(context, s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Semaine ${s.numero}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(_periode(s.lundi), style: const TextStyle(color: StatusColors.muted, fontSize: 12.5)),
                ]),
              ),
              _Pastille(auto: s.auto),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _Chiffre('${s.visites}', s.visites > 1 ? 'visites' : 'visite'),
              if (s.pourcentPrevu != null) _Chiffre('${s.pourcentPrevu} %', 'du prévu'),
              _Chiffre('${s.rdv}', s.rdv > 1 ? 'RDV obtenus' : 'RDV obtenu'),
            ]),
            if (pied.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(pied, style: const TextStyle(color: StatusColors.muted, fontSize: 11.5)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: [
      TextSpan(text: valeur, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      TextSpan(text: ' $libelle', style: const TextStyle(color: StatusColors.muted, fontSize: 12.5)),
    ]),
  );
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.auto});

  final bool auto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: auto ? const Color(0xFFF1F2F6) : const Color(0xFFD9F7E4), borderRadius: BorderRadius.circular(10)),
    child: Text(
      auto ? 'Validé auto' : 'Validé',
      style: TextStyle(color: auto ? const Color(0xFF4B5563) : const Color(0xFF047857), fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

/// Les lignes du rapport validé (la tournée réalisée de la semaine), en lecture seule.
void _ouvrirDetail(BuildContext context, RapportSemaine s) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Consumer(
        builder: (ctx, ref, _) {
          final etapes = ref.watch(etapesSemaineProvider(s.lundi)).value ?? const <EtapeTournee>[];
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Semaine ${s.numero} · ${_periode(s.lundi)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (etapes.isEmpty)
                const Text('Aucune ligne enregistrée sur cette semaine.', style: TextStyle(color: StatusColors.muted))
              else
                for (final e in etapes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(e.fait ? Icons.check_circle : Icons.radio_button_unchecked, color: e.fait ? StatusColors.ok : StatusColors.muted),
                    title: Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [
                        '${_joursCourts[e.jour.weekday - 1]} ${e.jour.day}',
                        if (e.heure != null) e.heure!,
                        if (e.rdv) 'RDV',
                        if (e.soireeEtape) 'Soirée étape',
                      ].join(' · '),
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
}
