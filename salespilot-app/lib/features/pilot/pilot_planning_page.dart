import '../prechargement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Nombre de prospects par colonne du planning de prospection, tiré de `GET /prospects/pipeline` (périmètre
/// appliqué par l'API). Regroupement des sept étapes en quatre colonnes — à valider avec le métier :
/// à contacter = NOUVEAU + CONTACTE · RDV pris = VISITE · en négo = PROPOSITION + NEGOCIATION · référencé = GAGNE.
class CompteursProspection {
  const CompteursProspection({required this.aContacter, required this.rdvPris, required this.enNego, required this.references});

  final int aContacter;
  final int rdvPris;
  final int enNego;
  final int references;

  factory CompteursProspection.fromPipeline(Map<String, dynamic> j) {
    final parEtape = <String, int>{
      for (final e in ((j['etapes'] as List?) ?? const []).cast<Map<String, dynamic>>()) e['statut'] as String: (e['total'] as num?)?.toInt() ?? 0,
    };
    int n(List<String> etapes) => etapes.fold(0, (a, s) => a + (parEtape[s] ?? 0));
    return CompteursProspection(
      aContacter: n(['NOUVEAU', 'CONTACTE']),
      rdvPris: n(['VISITE']),
      enNego: n(['PROPOSITION', 'NEGOCIATION']),
      references: n(['GAGNE']),
    );
  }
}

/// Lit le serveur et met la copie locale à jour. Lève une erreur si le serveur est injoignable.
Future<CompteursProspection> chargerCompteursProspectionReseau(Ref ref, String userId) async {
  final res = await ref.read(dioProvider).get<Map<String, dynamic>>('/prospects/pipeline');
  final raw = <String, dynamic>{
    'etapes': [
      for (final e in ((res.data?['etapes'] as List?) ?? const []).cast<Map<String, dynamic>>()) {'statut': e['statut'], 'total': e['total']},
    ],
  };
  await ref.read(cacheRepositoryProvider).put(userId, 'pipeline-compteurs', raw);
  return CompteursProspection.fromPipeline(raw);
}

/// Copie locale d'abord ; null (« — » à l'écran) si jamais chargé et que le réseau manque.
final compteursProspectionProvider = FutureProvider.autoDispose<CompteursProspection?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final cached = await ref.read(cacheRepositoryProvider).get(userId, 'pipeline-compteurs');
  if (cached != null) return CompteursProspection.fromPipeline(Map<String, dynamic>.from(cached.value as Map));
  try {
    return await chargerCompteursProspectionReseau(ref, userId);
  } on Object {
    return null;
  }
});

const _joursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];
const _joursLongs = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _moisLongs = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// Numéro de semaine ISO 8601.
int semaineIso(DateTime d) {
  final jeudi = DateTime(d.year, d.month, d.day).add(Duration(days: 4 - d.weekday));
  final premierJanvier = DateTime(jeudi.year, 1, 1);
  return 1 + jeudi.difference(premierJanvier).inDays ~/ 7;
}

/// Lundi de la semaine de [d].
DateTime lundiDe(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Planning de prospection d'ABC Pilot (maquette) : semaine, compteurs du pipeline, créneaux du jour.
///
/// Les créneaux (réunions, rendez-vous prospect, accompagnements, négociations) demandent un agenda côté serveur
/// qui n'existe pas encore : la liste est vide tant que l'API ne le fournit pas.
class PilotPlanningPage extends ConsumerStatefulWidget {
  const PilotPlanningPage({super.key});

  @override
  ConsumerState<PilotPlanningPage> createState() => _PilotPlanningPageState();
}

class _PilotPlanningPageState extends ConsumerState<PilotPlanningPage> {
  late DateTime _lundi;
  late DateTime _jour;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _lundi = lundiDe(now);
    // Le week-end n'a pas de colonne : on tombe sur le vendredi de la semaine affichée.
    _jour = DateTime(now.year, now.month, now.day);
    if (_jour.weekday > 5) _jour = _lundi.add(const Duration(days: 4));
  }

  void _changerSemaine(int delta) => setState(() {
        _lundi = _lundi.add(Duration(days: 7 * delta));
        _jour = _lundi.add(Duration(days: _jour.weekday > 5 ? 4 : _jour.weekday - 1));
      });

  void _bientot(String nom) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$nom : bientôt disponible.')));

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final compteurs = ref.watch(compteursProspectionProvider).value;
    final jours = [for (var i = 0; i < 5; i++) _lundi.add(Duration(days: i))];
    final auj = DateTime.now();
    bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Planning de prospection', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          '${_moisLongs[_jour.month - 1][0].toUpperCase()}${_moisLongs[_jour.month - 1].substring(1)} ${_jour.year} · semaine ${semaineIso(_lundi)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ]),
                    ),
                    _BoutonRond(icon: Icons.chevron_left, onTap: () => _changerSemaine(-1), tooltip: 'Semaine précédente'),
                    const SizedBox(width: 6),
                    _BoutonRond(icon: Icons.chevron_right, onTap: () => _changerSemaine(1), tooltip: 'Semaine suivante'),
                    const SizedBox(width: 6),
                    _BoutonRond(icon: Icons.filter_alt_outlined, onTap: () => _bientot('Filtres'), tooltip: 'Filtres'),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    for (var i = 0; i < jours.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Jour(
                          nom: _joursCourts[i],
                          numero: jours[i].day,
                          actif: memeJour(jours[i], _jour),
                          aujourdhui: memeJour(jours[i], auj),
                          onTap: () => setState(() => _jour = jours[i]),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: _Compteur(valeur: compteurs?.aContacter, label: 'À contacter')),
                    const SizedBox(width: 8),
                    Expanded(child: _Compteur(valeur: compteurs?.rdvPris, label: 'RDV pris')),
                    const SizedBox(width: 8),
                    Expanded(child: _Compteur(valeur: compteurs?.enNego, label: 'En négo')),
                    const SizedBox(width: 8),
                    Expanded(child: _Compteur(valeur: compteurs?.references, label: 'Référencé', accent: true)),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Text('${_joursLongs[_jour.weekday - 1]} ${_jour.day} ${_moisLongs[_jour.month - 1]}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    const Text('0 créneau', style: TextStyle(color: StatusColors.muted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 14),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun créneau. L\'agenda de prospection (réunions, rendez-vous, accompagnements) n\'est pas encore relié au serveur.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: StatusColors.muted),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _bientot('Nouveau RDV'),
            backgroundColor: violet,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.add),
            label: const Text('Nouveau RDV', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      );
}

class _Jour extends StatelessWidget {
  const _Jour({required this.nom, required this.numero, required this.actif, required this.aujourdhui, required this.onTap});

  final String nom;
  final int numero;
  final bool actif;
  final bool aujourdhui;
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
          Text(nom, style: TextStyle(color: actif ? violet : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$numero', style: TextStyle(color: actif ? const Color(0xFF111827) : Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          // Point sous le jour courant (maquette : point sous les jours qui ont des créneaux).
          Container(width: 5, height: 5, decoration: BoxDecoration(color: aujourdhui ? (actif ? violet : Colors.white) : Colors.transparent, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.label, this.accent = false});

  final int? valeur;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: accent ? violet.withValues(alpha: .10) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent ? Colors.transparent : const Color(0xFFE8EAF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valeur == null ? '—' : '$valeur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent ? violet : null)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: accent ? FontWeight.w800 : FontWeight.w500, color: accent ? violet : StatusColors.muted)),
        ),
      ]),
    );
  }
}
