import '../prechargement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'tournee_etapes.dart';

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

/// Ma tournée de prospection (onglet « Tournée » d'ABC Pilot) : la semaine, puis les étapes du jour.
///
/// Les étapes sont celles de MA tournée (`/tournees/me`, les mêmes que sur le web) : visites de magasins ou de
/// prospects, accompagnements, RDV. Le bouton « Saisir le rapport » ouvre le formulaire qui en ajoute une ; tant
/// qu'elle n'est pas partie sur le serveur, elle s'affiche « En attente d'envoi ».
class PilotTourneePage extends ConsumerStatefulWidget {
  const PilotTourneePage({super.key});

  @override
  ConsumerState<PilotTourneePage> createState() => _PilotTourneePageState();
}

class _PilotTourneePageState extends ConsumerState<PilotTourneePage> {
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

  Future<void> _nouveauRdv() async {
    final jour = await context.push<DateTime>('/rdv/nouveau?date=${jourIso(_jour)}');
    // On se place sur le jour du rendez-vous ajouté, dans la semaine qui le contient.
    if (jour != null && mounted) {
      setState(() {
        _lundi = lundiDe(jour);
        _jour = DateTime(jour.year, jour.month, jour.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final jours = [for (var i = 0; i < 5; i++) _lundi.add(Duration(days: i))];
    bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

    // Étapes de la semaine : celles du serveur (copie locale) plus celles saisies et pas encore envoyées.
    final finSemaine = _lundi.add(const Duration(days: 7));
    final etapes = [
      ...(ref.watch(etapesSemaineProvider(_lundi)).value ?? const <EtapeTournee>[]),
      for (final e in ref.watch(etapesEnAttenteProvider).value ?? const <EtapeTournee>[])
        if (!e.jour.isBefore(_lundi) && e.jour.isBefore(finSemaine)) e,
    ];
    List<EtapeTournee> duJour(DateTime d) => [for (final e in etapes) if (memeJour(e.jour, d)) e]
      ..sort((a, b) => (a.heure ?? '99:99').compareTo(b.heure ?? '99:99'));
    final etapesJour = duJour(_jour);
    final faites = etapesJour.where((e) => e.fait).length;
    // Une étape part (ou est refusée) : on relit la semaine pour que la liste suive le serveur.
    ref.listen(etapesEnAttenteProvider, (_, _) => ref.read(miseAJourLocaleProvider).etapes(_lundi));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(children: [
        RefreshIndicator(
          onRefresh: () async {
            await ref.read(miseAJourLocaleProvider).etapes(_lundi);
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
                        const Text('Ma tournée de prospection', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
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
                    _BoutonRond(icon: Icons.map_outlined, onTap: () => _bientot('Carte de la tournée'), tooltip: 'Carte'),
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
                          rdv: duJour(jours[i]).length,
                          onTap: () => setState(() => _jour = jours[i]),
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
                    Expanded(child: Text('${_joursLongs[_jour.weekday - 1]} ${_jour.day} ${_moisLongs[_jour.month - 1]}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    if (etapesJour.isNotEmpty) Text('$faites / ${etapesJour.length} faites', style: const TextStyle(color: StatusColors.muted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 14),
                  if (etapesJour.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucune étape ce jour. Touchez « Saisir le rapport » pour planifier un rendez-vous.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: StatusColors.muted),
                        ),
                      ),
                    )
                  else
                    for (final e in etapesJour) _Etape(etape: e),
                ]),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _nouveauRdv,
            backgroundColor: violet,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Saisir le rapport', style: TextStyle(fontWeight: FontWeight.w800)),
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

/// Couleurs d'une étape selon son état (maquette) : fait (vert), négociation (jaune), prospect (bleu), client (violet).
({String libelle, Color fond, Color titre}) _style(EtapeTournee e) {
  if (e.fait) return (libelle: 'Fait ✓', fond: const Color(0xFFDDF5E6), titre: const Color(0xFF166534));
  if (e.type == 'ADM') return (libelle: 'ADM', fond: const Color(0xFFEDEFF3), titre: const Color(0xFF374151));
  if (e.type == 'PROSPECT') {
    final negociation = e.statutProspect == 'PROPOSITION' || e.statutProspect == 'NEGOCIATION';
    return negociation
        ? (libelle: 'Négo', fond: const Color(0xFFFCEFC6), titre: const Color(0xFF92400E))
        : (libelle: 'Prospect', fond: const Color(0xFFDFE8FF), titre: const Color(0xFF1E3A8A));
  }
  return (libelle: 'Client', fond: const Color(0xFFEBE5FF), titre: const Color(0xFF5B21B6));
}

/// Une étape du jour : heure à gauche, carte colorée à droite (enseigne – ville, qualification, note, statut).
class _Etape extends StatelessWidget {
  const _Etape({required this.etape});

  final EtapeTournee etape;

  @override
  Widget build(BuildContext context) {
    final s = _style(etape);
    final details = [
      if (etape.accompagnement) 'Accompagnement' else if (etape.visiteSimple) 'Visite simple',
      if (etape.rdv) 'RDV',
      if (etape.soireeEtape) 'Soirée étape${(etape.soireeLieu ?? '').isEmpty ? '' : ' (${etape.soireeLieu})'}',
      if ((etape.note ?? '').isNotEmpty) etape.note!,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(etape.heure ?? '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(color: s.fond, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    '${etape.titre}${etape.ville == null ? '' : ' – ${etape.ville}'}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: s.titre),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text(s.libelle, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: s.titre)),
                ),
              ]),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(details.join(' · '), style: TextStyle(fontSize: 12.5, color: s.titre.withValues(alpha: .85))),
              ],
              if (etape.enAttente) ...[
                const SizedBox(height: 6),
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_send_outlined, size: 14, color: StatusColors.warn),
                  SizedBox(width: 4),
                  Text('En attente d\'envoi', style: TextStyle(fontSize: 12, color: StatusColors.warn, fontWeight: FontWeight.w700)),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Jour extends StatelessWidget {
  const _Jour({required this.nom, required this.numero, required this.actif, required this.rdv, required this.onTap});

  final String nom;
  final int numero;
  final bool actif;

  /// Nombre d'étapes du jour, affiché sous le numéro.
  final int rdv;
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
          const SizedBox(height: 2),
          Text('$rdv RDV', style: TextStyle(color: actif ? violet : Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
