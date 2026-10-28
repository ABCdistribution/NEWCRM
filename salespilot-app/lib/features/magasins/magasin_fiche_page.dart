import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/db/cache_repository.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_transport.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import '../tournee/tournee_page.dart' show dateCourte, montantCourt;
import '../visite/draft_repository.dart';
import 'magasin_repository.dart';

enum _Onglet { apercu, contacts, commandes, notes }

extension on _Onglet {
  String get label => switch (this) {
        _Onglet.apercu => 'Aperçu',
        _Onglet.contacts => 'Contacts',
        _Onglet.commandes => 'Commandes',
        _Onglet.notes => 'Notes',
      };
}

/// Fiche magasin (maquette) : en-tête bleu avec actions, onglets Aperçu / Contacts / Commandes / Notes.
class MagasinFichePage extends ConsumerStatefulWidget {
  const MagasinFichePage({super.key, required this.id, this.magasin});

  final String id;
  final Magasin? magasin;

  @override
  ConsumerState<MagasinFichePage> createState() => _FichePageState();
}

class _FichePageState extends ConsumerState<MagasinFichePage> {
  late Future<Cached<FicheMagasin>> _fiche;
  late Future<HistoriqueMagasin?> _historique;
  var _onglet = _Onglet.apercu;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    final userId = ref.read(currentUserIdProvider)!;
    final repo = ref.read(magasinRepositoryProvider);
    final base = widget.magasin ?? Magasin(id: widget.id, codeAs400: '', enseigne: 'Magasin');
    _fiche = repo.fiche(userId, widget.id, base);
    _historique = repo.historique(userId, widget.id);
  }

  void _message(String texte) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _ouvrir(Uri uri, String echec) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _message(echec);
    } on Object {
      _message(echec);
    }
  }

  Future<void> _appeler(FicheMagasin f) async {
    final numero = f.contacts.map((c) => c.portable ?? c.fixe).whereType<String>().where((s) => s.trim().isNotEmpty).firstOrNull ?? f.telephone;
    if (numero == null) return _message('Aucun numéro de téléphone pour ce magasin.');
    await _ouvrir(Uri(scheme: 'tel', path: numero.replaceAll(' ', '')), 'Impossible de lancer l\'appel.');
  }

  Future<void> _itineraire(FicheMagasin f) async {
    final Uri uri;
    if (f.latitude != null && f.longitude != null) {
      uri = Uri.parse('geo:${f.latitude},${f.longitude}?q=${f.latitude},${f.longitude}(${Uri.encodeComponent(f.magasin.enseigne)})');
    } else if (f.adresse != null) {
      uri = Uri.parse('geo:0,0?q=${Uri.encodeComponent(f.adresse!)}');
    } else {
      return _message('Adresse inconnue pour ce magasin.');
    }
    await _ouvrir(uri, 'Aucune application de cartes disponible.');
  }

  Future<void> _visite() async {
    final userId = ref.read(currentUserIdProvider)!;
    final id = await ref.read(visiteServiceProvider).startOrResume(userId: userId, clientId: widget.id, libelle: widget.magasin?.enseigne ?? 'Visite');
    if (mounted) context.push('/visite/$id');
  }

  Future<void> _ajouterNote() async {
    final ctrl = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouvelle note'),
        content: TextField(controller: ctrl, maxLines: 4, maxLength: 2000, autofocus: true, decoration: const InputDecoration(hintText: 'Votre remarque')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    ctrl.dispose();
    if (texte == null || texte.isEmpty) return;
    final userId = ref.read(currentUserIdProvider)!;
    final idApk = const Uuid().v4();
    // La note est écrite sur le téléphone puis envoyée : jamais perdue si le réseau manque.
    await ref.read(outboxRepositoryProvider).enqueue(
      userId: userId,
      kind: OutboxKind.note,
      idApk: idApk,
      payload: {'clientId': widget.id, 'remarque': texte, 'idApk': idApk},
    );
    ref.read(syncControllerProvider.notifier).run();
    if (mounted) _message('Note enregistrée. Envoi dès que le réseau le permet.');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: FutureBuilder<Cached<FicheMagasin>>(
        future: _fiche,
        builder: (context, snap) {
          final fiche = snap.data?.value;
          final base = widget.magasin ?? Magasin(id: widget.id, codeAs400: '', enseigne: 'Magasin');
          return ListView(padding: EdgeInsets.zero, children: [
            _Entete(
              magasin: fiche?.magasin ?? base,
              adresse: fiche?.adresse,
              onRetour: () => context.canPop() ? context.pop() : context.go('/magasins'),
              onAppeler: fiche == null ? null : () => _appeler(fiche),
              onItineraire: fiche == null ? null : () => _itineraire(fiche),
              onVisite: _visite,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _corps(snap),
            ),
          ]);
        },
      ),
    );
  }

  Widget _corps(AsyncSnapshot<Cached<FicheMagasin>> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    }
    if (snap.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text('${errorMessage(snap.error!)}\nOuvrez cette fiche une première fois avec du réseau pour l\'avoir hors ligne.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => setState(_charger), child: const Text('Réessayer')),
          ]),
        ),
      );
    }
    final cached = snap.data!;
    final fiche = cached.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (cached.fromCache)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Hors ligne — données du ${DateFormat('dd/MM HH:mm').format(cached.fetchedAt)}', style: const TextStyle(color: StatusColors.warn, fontSize: 12)),
        ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final o in _Onglet.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _OngletPuce(label: o.label, actif: _onglet == o, onTap: () => setState(() => _onglet = o)),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      FutureBuilder<HistoriqueMagasin?>(
        future: _historique,
        builder: (context, h) => switch (_onglet) {
          _Onglet.apercu => _Apercu(fiche: fiche, historique: h.data, chargement: h.connectionState != ConnectionState.done, clientId: widget.id),
          _Onglet.contacts => _Contacts(contacts: fiche.contacts),
          _Onglet.commandes => _Commandes(historique: h.data, chargement: h.connectionState != ConnectionState.done),
          _Onglet.notes => _Notes(notes: fiche.notes, onAjouter: _ajouterNote),
        },
      ),
    ]);
  }
}

class _Entete extends StatelessWidget {
  const _Entete({
    required this.magasin,
    required this.adresse,
    required this.onRetour,
    required this.onAppeler,
    required this.onItineraire,
    required this.onVisite,
  });

  final Magasin magasin;
  final String? adresse;
  final VoidCallback onRetour;
  final VoidCallback? onAppeler;
  final VoidCallback? onItineraire;
  final VoidCallback onVisite;

  @override
  Widget build(BuildContext context) {
    final bleu = SpacePalette.sales.accent;
    final statut = '${magasin.actif ? 'Client actif' : 'Client inactif'}${magasin.niveauClass == null ? '' : ' · ${magasin.niveauClass}'}';
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 18),
      decoration: BoxDecoration(color: bleu, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onRetour,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(statut, style: TextStyle(color: bleu, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(magasin.libelle.replaceFirst(' — ', ' – '), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          [?adresse, if (magasin.codeAs400.isNotEmpty) 'Code ${magasin.codeAs400}'].join(' · '),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Action(icon: Icons.phone_outlined, label: 'Appeler', onTap: onAppeler)),
          const SizedBox(width: 8),
          Expanded(child: _Action(icon: Icons.near_me_outlined, label: 'Itinéraire', onTap: onItineraire)),
          const SizedBox(width: 8),
          Expanded(child: _Action(icon: Icons.add, label: 'Visite', onTap: onVisite, plein: true)),
        ]),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.plein = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool plein;

  @override
  Widget build(BuildContext context) {
    final fg = plein ? SpacePalette.sales.accent : Colors.white;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(color: plein ? Colors.white : Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

class _OngletPuce extends StatelessWidget {
  const _OngletPuce({required this.label, required this.actif, required this.onTap});

  final String label;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(color: actif ? const Color(0xFF0B1530) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Text(label, style: TextStyle(color: actif ? Colors.white : const Color(0xFF374151), fontWeight: actif ? FontWeight.w800 : FontWeight.w600)),
        ),
      );
}

// --- Aperçu -------------------------------------------------------------------------------------------------------------

class _Apercu extends ConsumerWidget {
  const _Apercu({required this.fiche, required this.historique, required this.chargement, required this.clientId});

  final FicheMagasin fiche;
  final HistoriqueMagasin? historique;
  final bool chargement;
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final m = fiche.magasin;
    final evo = historique?.evolutionCumul(now);
    final principal = fiche.contacts.firstOrNull;
    final drafts = (ref.watch(draftsProvider).value ?? const []).where((d) => d.clientId == clientId).toList();

    final evenements = <_Evenement>[
      for (final d in drafts.where((d) => d.state == VisiteState.brouillon))
        _Evenement(date: d.updatedAt, titre: 'Visite en cours', detail: 'Brouillon sur ce téléphone', couleur: SpacePalette.sales.accent, local: true),
      for (final v in historique?.visites ?? const <VisiteMagasin>[])
        if (v.date != null)
          _Evenement(
            date: v.date!,
            titre: 'Visite',
            detail: [if (v.photos > 0) '${v.photos} photo${v.photos > 1 ? 's' : ''}', ?v.promoteur].join(' · '),
            couleur: StatusColors.ok,
          ),
      for (final c in historique?.commandes ?? const <CommandeMagasin>[])
        if (c.date != null)
          _Evenement(
            date: c.date!,
            titre: c.annulee ? 'Commande annulée' : 'Commande validée',
            detail: '${NumberFormat('#,##0', 'fr').format(c.total)} € · ${c.nbLignes} référence${c.nbLignes > 1 ? 's' : ''}',
            couleur: c.annulee ? StatusColors.alert : StatusColors.ok,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _Kpi(
            label: 'CA 12 mois',
            valeur: historique == null ? '—' : montantCourt(historique!.ca12Mois(now)),
            sous: evo == null ? null : '${evo >= 0 ? '+' : ''}${evo.round()} % vs N-1',
            sousCouleur: (evo ?? 0) >= 0 ? StatusColors.ok : StatusColors.alert,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Kpi(
            label: 'Dernière visite',
            valeur: m.derniereVisiteJours == null ? 'Jamais' : '${m.derniereVisiteJours} j',
            sous: m.derniereVisiteJours == null ? null : 'il y a ${m.derniereVisiteJours} jour${m.derniereVisiteJours! > 1 ? 's' : ''}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _Kpi(label: 'Fréquence', valeur: fiche.periodicite ?? '—', sous: 'Périodicité', petit: true)),
      ]),
      const SizedBox(height: 12),
      if (principal != null) _ContactCarte(contact: principal),
      if (principal != null) const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _carte,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Historique', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 12),
          if (chargement && evenements.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (evenements.isEmpty)
            const Text('Aucun historique disponible.', style: TextStyle(color: StatusColors.muted))
          else
            for (var i = 0; i < evenements.take(8).length; i++) _LigneHistorique(e: evenements[i], derniere: i == evenements.take(8).length - 1),
        ]),
      ),
    ]);
  }
}

final _carte = BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8EAF2)));

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.valeur, this.sous, this.sousCouleur, this.petit = false});

  final String label;
  final String valeur;
  final String? sous;
  final Color? sousCouleur;
  final bool petit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: _carte,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: StatusColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, style: TextStyle(fontSize: petit ? 15 : 22, fontWeight: FontWeight.w800)),
          ),
          if (sous != null) ...[
            const SizedBox(height: 2),
            Text(sous!, style: TextStyle(color: sousCouleur ?? const Color(0xFF374151), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ]),
      );
}

String _initiales(String nom) =>
    nom.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

class _ContactCarte extends StatelessWidget {
  const _ContactCarte({required this.contact});

  final ContactMagasin contact;

  @override
  Widget build(BuildContext context) {
    final bleu = SpacePalette.sales.accent;
    final role = contact.typePoste;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _carte,
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: bleu.withValues(alpha: .12),
          child: Text(_initiales(contact.nom), style: TextStyle(color: bleu, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.nom.isEmpty ? 'Contact' : contact.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            if (contact.poste != null && contact.poste!.isNotEmpty) Text(contact.poste!, style: const TextStyle(color: StatusColors.muted, fontSize: 13)),
          ]),
        ),
        if (role != null && role.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bleu.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Text(role, style: TextStyle(color: bleu, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _Evenement {
  const _Evenement({required this.date, required this.titre, required this.detail, required this.couleur, this.local = false});

  final DateTime date;
  final String titre;
  final String detail;
  final Color couleur;
  final bool local;
}

String _dateHistorique(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Aujourd\'hui';
  final s = dateCourte(d).split(' ').skip(1).join(' '); // « 14 oct. » sans le jour de la semaine
  return d.year == now.year ? s : '$s ${d.year}';
}

class _LigneHistorique extends StatelessWidget {
  const _LigneHistorique({required this.e, required this.derniere});

  final _Evenement e;
  final bool derniere;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 22,
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 5), width: 11, height: 11, decoration: BoxDecoration(color: e.couleur, shape: BoxShape.circle)),
              if (!derniere) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: const Color(0xFFE5E7EB))),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: derniere ? 0 : 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Text(_dateHistorique(e.date), style: const TextStyle(color: StatusColors.muted, fontSize: 12)),
                ]),
                if (e.detail.isNotEmpty) Text(e.detail, style: const TextStyle(color: StatusColors.muted, fontSize: 13)),
              ]),
            ),
          ),
        ]),
      );
}

// --- Contacts, commandes, notes ---------------------------------------------------------------------------------------

class _Contacts extends StatelessWidget {
  const _Contacts({required this.contacts});

  final List<ContactMagasin> contacts;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const _Vide('Aucun contact.');
    return Column(children: [
      for (final c in contacts)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              title: Text(c.nom.isEmpty ? 'Contact' : c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([c.poste, c.portable ?? c.fixe, c.mail].whereType<String>().where((s) => s.isNotEmpty).join('\n')),
              isThreeLine: [c.poste, c.portable ?? c.fixe, c.mail].whereType<String>().where((s) => s.isNotEmpty).length > 2,
            ),
          ),
        ),
    ]);
  }
}

class _Commandes extends StatelessWidget {
  const _Commandes({required this.historique, required this.chargement});

  final HistoriqueMagasin? historique;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    if (chargement && historique == null) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    final list = historique?.commandes ?? const <CommandeMagasin>[];
    if (list.isEmpty) return _Vide(historique == null ? 'Historique indisponible hors ligne.' : 'Aucune commande.');
    return Column(children: [
      for (final c in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              title: Text('${NumberFormat('#,##0', 'fr').format(c.total)} € · ${c.nbLignes} référence${c.nbLignes > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([if (c.numero != null) 'N° ${c.numero}', if (c.annulee) 'Annulée'].join(' · ')),
              trailing: Text(c.date == null ? '' : _dateHistorique(c.date!), style: const TextStyle(color: StatusColors.muted, fontSize: 12)),
            ),
          ),
        ),
    ]);
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes, required this.onAjouter});

  final List<NoteMagasin> notes;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton.icon(onPressed: onAjouter, icon: const Icon(Icons.add), label: const Text('Ajouter une note')),
        const SizedBox(height: 10),
        if (notes.isEmpty) const _Vide('Aucune note.'),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(n.remarque),
                subtitle: n.date == null ? null : Text(DateFormat('dd/MM/yyyy HH:mm').format(n.date!)),
              ),
            ),
          ),
      ]);
}

class _Vide extends StatelessWidget {
  const _Vide(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(texte, style: const TextStyle(color: StatusColors.muted))),
      );
}
