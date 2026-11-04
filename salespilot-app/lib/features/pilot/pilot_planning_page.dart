import '../prechargement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'pilot_prospect_fiche_page.dart' show ouvrirFicheDeLigne;
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
  bool _action = false;

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

  void _message(String texte) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texte)));

  /// Ouvre le formulaire (ajout d'une ligne, ou modification de [etape]) puis se place sur le jour concerné.
  Future<void> _ouvrirFormulaire({EtapeTournee? etape}) async {
    final jour = etape == null
        ? await context.push<DateTime>('/rdv/nouveau?date=${jourIso(_jour)}')
        : await context.push<DateTime>('/rdv/nouveau', extra: etape);
    // On se place sur le jour de la ligne, dans la semaine qui le contient.
    if (jour != null && mounted) {
      setState(() {
        _lundi = lundiDe(jour);
        _jour = DateTime(jour.year, jour.month, jour.day);
      });
    }
  }

  Future<void> _nouveauRdv() => _ouvrirFormulaire();

  void _modifier(EtapeTournee e, EtatSemaine etat) {
    if (etat.verrouillee) return _message('Rapport validé : plus rien n\'est modifiable.');
    if (e.enAttente) return _message('Cette ligne n\'est pas encore envoyée : elle pourra être modifiée dès son envoi.');
    _ouvrirFormulaire(etape: e);
  }

  /// Exécute une action du rapport auprès du serveur (en ligne), puis affiche le résultat ou le motif du refus.
  Future<void> _executer(Future<void> Function() action, String succes) async {
    setState(() => _action = true);
    try {
      await action();
      if (mounted) _message(succes);
    } on Object catch (e) {
      final horsLigne = e is DioException && e.response == null;
      if (mounted) _message(horsLigne ? 'Connexion requise pour cette action.' : errorMessage(e));
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _enregistrerPrevision() =>
      _executer(() => ref.read(rapportActionsProvider).enregistrerPrevision(_lundi), 'Prévision enregistrée.');

  Future<void> _validerRapport(int enAttente) async {
    if (enAttente > 0) {
      return _message('$enAttente ligne${enAttente > 1 ? 's' : ''} en attente d\'envoi : elles doivent d\'abord partir sur le serveur. Connectez-vous puis réessayez.');
    }
    final confirme = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Valider le rapport ?'),
        content: const Text('La tournée réalisée devient définitive et la semaine est verrouillée : plus rien ne sera modifiable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _executer(() => ref.read(rapportActionsProvider).validerRapport(_lundi), 'Rapport validé.');
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
    final etat = ref.watch(etatSemaineProvider(_lundi)).value ?? EtatSemaine.vierge(_lundi);
    final prevue = ref.watch(prevueSemaineProvider(_lundi)).value;
    final enAttenteSemaine = etapes.where((e) => e.enAttente).length;
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
                        const Text('Mon planning', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
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
                  _BandeauRapport(
                    etat: etat,
                    nbLignes: etapes.length,
                    occupe: _action,
                    onPrevision: _enregistrerPrevision,
                    onValider: () => _validerRapport(enAttenteSemaine),
                  ),
                  // Dès le mardi la prévision est figée : on la garde sous les yeux pour comparer au réalisé.
                  if (etat.phase == PhaseSemaine.rapport) _PrevueSemaine(lignes: prevue),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Text('${_joursLongs[_jour.weekday - 1]} ${_jour.day} ${_moisLongs[_jour.month - 1]}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    if (etapesJour.isNotEmpty) Text('$faites / ${etapesJour.length} faites', style: const TextStyle(color: StatusColors.muted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 14),
                  if (etapesJour.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          etat.verrouillee ? 'Aucune ligne ce jour.' : 'Aucune étape ce jour. Touchez « Saisir le rapport » pour ajouter une ligne.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: StatusColors.muted),
                        ),
                      ),
                    )
                  else
                    // Un appui ouvre la fiche du magasin ou du prospect ; le crayon modifie la ligne du rapport.
                    for (final e in etapesJour)
                      _Etape(
                        etape: e,
                        onTap: () {
                          if (!ouvrirFicheDeLigne(context, e)) _modifier(e, etat);
                        },
                        onModifier: () => _modifier(e, etat),
                      ),
                ]),
              ),
            ],
          ),
        ),
        if (!etat.verrouillee)
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
  if (e.type == 'LIBRE') return (libelle: 'Libre', fond: const Color(0xFFEFEFEF), titre: const Color(0xFF374151));
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
  const _Etape({required this.etape, required this.onTap, required this.onModifier});

  final EtapeTournee etape;
  final VoidCallback onTap;
  final VoidCallback onModifier;

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
          child: Material(
            color: s.fond,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                // Ligne liée à une fiche : l'appui ouvre la fiche, le crayon ouvre la ligne du rapport.
                if (etape.type == 'CLIENT' || etape.type == 'PROSPECT')
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onModifier,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.edit_outlined, size: 18, color: s.titre),
                    ),
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

String _dateHeure(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Les trois temps du rapport de la semaine : prévision (jusqu'au lundi soir), rapport en cours (dès le mardi), validé.
class _BandeauRapport extends StatelessWidget {
  const _BandeauRapport({required this.etat, required this.nbLignes, required this.occupe, required this.onPrevision, required this.onValider});

  final EtatSemaine etat;
  final int nbLignes;
  final bool occupe;
  final VoidCallback onPrevision;
  final VoidCallback onValider;

  @override
  Widget build(BuildContext context) {
    final p = SpacePalette.pilot;
    final IconData icone;
    final Color couleur;
    final String titre;
    final String detail;
    if (etat.verrouillee) {
      icone = etat.valideAuto ? Icons.lock_clock_outlined : Icons.verified_outlined;
      couleur = StatusColors.ok;
      titre = '${etat.valideAuto ? 'Validé auto' : 'Rapport validé'} le ${_dateHeure(etat.valideAt!)}';
      detail = 'La semaine est verrouillée : plus rien n\'est modifiable.';
    } else if (etat.phase == PhaseSemaine.prevision) {
      icone = etat.prevuAt == null ? Icons.edit_calendar_outlined : Icons.save_outlined;
      couleur = p.accent;
      titre = etat.prevuAt == null ? 'Prévision à saisir' : 'Prévision enregistrée le ${_dateHeure(etat.prevuAt!)}';
      detail = 'Modifiable jusqu\'au lundi soir : le rapport se valide à partir du mardi.';
    } else {
      icone = Icons.hourglass_top_outlined;
      couleur = StatusColors.warn;
      titre = 'Rapport en cours';
      final n = etat.nbEtapesPrevues ?? 0;
      detail = etat.previsionNonRenseignee
          ? 'Prévision non renseignée. Corrigez les lignes pour refléter la réalité, puis validez.'
          : 'Prévision figée ($n ligne${n > 1 ? 's' : ''}). Corrigez les lignes pour refléter la réalité, puis validez.';
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icone, color: couleur, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
          ]),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 12.5, color: StatusColors.muted)),
          if (etat.previsionModifiable) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: occupe || nbLignes == 0 ? null : onPrevision,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(etat.prevuAt == null ? 'Enregistrer la prévision' : 'Mettre à jour la prévision'),
            ),
          ],
          if (etat.peutValider) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: occupe ? null : onValider,
              style: FilledButton.styleFrom(backgroundColor: p.bouton, foregroundColor: p.surBouton),
              icon: occupe
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Valider le rapport'),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Tournée prévue de la semaine (la photographie figée dès le mardi), à comparer à la tournée réalisée.
class _PrevueSemaine extends StatelessWidget {
  const _PrevueSemaine({required this.lignes});

  /// null : prévision non renseignée (ou inconnue hors ligne).
  final List<EtapeTournee>? lignes;

  @override
  Widget build(BuildContext context) {
    final l = lignes;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.assignment_outlined),
        title: const Text('Tournée prévue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        subtitle: Text(l == null ? 'non renseignée' : '${l.length} ligne${l.length > 1 ? 's' : ''} · figée', style: const TextStyle(fontSize: 12.5)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (l == null || l.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('La prévision n\'a pas été renseignée cette semaine.', style: TextStyle(color: StatusColors.muted)),
            )
          else
            for (final e in l)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      '${_joursCourts[(e.jour.weekday - 1).clamp(0, 4)]} ${e.jour.day}${e.heure == null ? '' : ' ${e.heure}'}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text('${e.titre}${e.ville == null ? '' : ' – ${e.ville}'}', style: const TextStyle(fontSize: 13))),
                ]),
              ),
        ],
      ),
    );
  }
}
