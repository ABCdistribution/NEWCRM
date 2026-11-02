import '../prechargement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/role.dart';
import '../../core/config.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import '../shell/app_shell.dart';
import '../shell/selecteur_espace.dart';
import '../visite/draft_repository.dart';
import 'tournee_repository.dart';

/// État affiché d'une visite planifiée.
enum EtatVisite { aFaire, enCours, enAttenteEnvoi, realisee }

extension EtatVisiteLabel on EtatVisite {
  String get label => switch (this) {
    EtatVisite.aFaire => 'À venir',
    EtatVisite.enCours => 'En cours',
    EtatVisite.enAttenteEnvoi => 'À envoyer',
    EtatVisite.realisee => 'Terminée',
  };

  Color get color => switch (this) {
    EtatVisite.aFaire => StatusColors.muted,
    EtatVisite.enCours => SpacePalette.sales.accent,
    EtatVisite.enAttenteEnvoi => StatusColors.warn,
    EtatVisite.realisee => StatusColors.ok,
  };

  IconData get icon => switch (this) {
    EtatVisite.aFaire => Icons.schedule,
    EtatVisite.enCours => Icons.location_on_outlined,
    EtatVisite.enAttenteEnvoi => Icons.cloud_upload_outlined,
    EtatVisite.realisee => Icons.check,
  };
}

/// Croise une visite planifiée et les visites saisies sur le téléphone pour en déduire son état.
EtatVisite etatDe(PlanningItem p, List<VisiteDraft> drafts) {
  final d = drafts.where((d) => d.planningId == p.id).firstOrNull;
  if (p.fait || d?.state == VisiteState.synchronisee) {
    return EtatVisite.realisee;
  }
  return switch (d?.state) {
    VisiteState.terminee => EtatVisite.enAttenteEnvoi,
    VisiteState.brouillon => EtatVisite.enCours,
    _ => EtatVisite.aFaire,
  };
}

const _jours = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const _mois = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// « Mer. 28 oct. » (écrit à la main : ne dépend pas des données de langue chargées).
String dateCourte(DateTime d) =>
    '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

/// « 4,8 k€ » à partir de 1 000 €, sinon « 850 € ».
String montantCourt(double v) {
  if (v >= 1000) return '${NumberFormat('#,##0.#', 'fr').format(v / 1000)} k€';
  return '${NumberFormat('#,##0', 'fr').format(v)} €';
}

/// Accueil = tournée du jour (CDC §3.2), d'après la maquette : en-tête bleu, raccourcis, tournée.
class TourneePage extends ConsumerWidget {
  const TourneePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournee = ref.watch(tourneeProvider);
    final drafts = ref.watch(draftsProvider).value ?? const <VisiteDraft>[];
    final objectif = ref.watch(objectifMoisProvider).value;
    final items = tournee.value?.items ?? const <PlanningItem>[];
    final realisees = items
        .where((p) => etatDe(p, drafts) == EtatVisite.realisee)
        .length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          final maj = ref.read(miseAJourLocaleProvider);
          await Future.wait([maj.tournee(), maj.objectif()]);
          ref.read(syncControllerProvider.notifier).run();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Entete(
              visites: tournee.hasValue ? '$realisees' : '—',
              prevues: tournee.hasValue ? '${items.length}' : null,
              commande: objectif == null ? '—' : montantCourt(objectif.realise),
              objectif: objectif?.tauxPct == null
                  ? '—'
                  : '${objectif!.tauxPct} %',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Raccourcis(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ma tournée du jour',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dateCourte(DateTime.now()),
                          style: const TextStyle(
                            color: StatusColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  tournee.when(
                    skipLoadingOnReload: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => _Erreur(
                      message: errorMessage(e),
                      onRetry: () => ref.invalidate(tourneeProvider),
                    ),
                    data: (t) => _Contenu(tournee: t, drafts: drafts),
                  ),
                  _Brouillons(drafts: drafts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête bleu : salutation, indicateur de synchronisation, sélecteur d'espace et trois chiffres.
class _Entete extends ConsumerWidget {
  const _Entete({
    required this.visites,
    required this.prevues,
    required this.commande,
    required this.objectif,
  });

  final String visites;
  final String? prevues;
  final String commande;
  final String objectif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;
    final prenom = (user?.displayName ?? '')
        .split(' ')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final initiales = (user?.displayName ?? '?')
        .split(' ')
        .where((s) => s.isNotEmpty && RegExp('[A-Za-zÀ-ÿ]').hasMatch(s[0]))
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    final bleu = SpacePalette.sales.accent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 14,
        16,
        18,
      ),
      decoration: BoxDecoration(
        color: bleu,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/profil'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(
                    initiales.isEmpty ? '?' : initiales,
                    style: TextStyle(color: bleu, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour $prenom',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      user?.role.label ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const PendingBadge(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SelecteurEspace(space: Space.sales),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Chiffre(
                  label: 'Visites',
                  valeur: visites,
                  suite: prevues == null ? null : ' / $prevues',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chiffre(label: 'Commandé', valeur: commande),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chiffre(label: 'Objectif mois', valeur: objectif),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.label, required this.valeur, this.suite});

  final String label;
  final String valeur;
  final String? suite;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: valeur,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (suite != null)
                  TextSpan(
                    text: suite,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Quatre raccourcis. Commande et Photo rayon arrivent avec leurs modules (CDC §3.5 et §3.6).
class _Raccourcis extends StatelessWidget {
  const _Raccourcis();

  @override
  Widget build(BuildContext context) {
    void bientot(String nom) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$nom : bientôt disponible.')));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Raccourci(
          icon: Icons.shopping_cart_outlined,
          label: 'Commande',
          onTap: () => bientot('Commande'),
        ),
        _Raccourci(
          icon: Icons.location_on_outlined,
          label: 'Visite',
          onTap: () => context.go('/magasins?pick=1'),
        ),
        _Raccourci(
          icon: Icons.photo_camera_outlined,
          label: 'Photo rayon',
          onTap: () => bientot('Photo rayon'),
        ),
        _Raccourci(
          icon: Icons.storefront_outlined,
          label: 'Magasins',
          onTap: () => context.go('/magasins'),
        ),
      ],
    );
  }
}

class _Raccourci extends StatelessWidget {
  const _Raccourci({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: SpacePalette.sales.accent),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.tournee, required this.drafts});

  final TourneeJour tournee;
  final List<VisiteDraft> drafts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = tournee.items;
    final etats = {for (final p in items) p.id: etatDe(p, drafts)};
    final heure = DateFormat('HH:mm').format(tournee.fetchedAt);
    // Le bouton « Démarrer » n'apparaît que sur la prochaine visite, sauf si une visite est déjà en cours.
    final enCours = etats.values.contains(EtatVisite.enCours);
    final prochaine = enCours
        ? null
        : items.where((p) => etats[p.id] == EtatVisite.aFaire).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tournee.fromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hors ligne — données de $heure',
              style: const TextStyle(color: StatusColors.warn, fontSize: 12),
            ),
          ),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune visite planifiée aujourd\'hui. Utilisez « Visite » pour en enregistrer une non planifiée.',
                textAlign: TextAlign.center,
                style: TextStyle(color: StatusColors.muted),
              ),
            ),
          ),
        for (final p in items) ...[
          _VisiteTile(
            item: p,
            etat: etats[p.id]!,
            demarrer: p.id == prochaine?.id,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _VisiteTile extends ConsumerWidget {
  const _VisiteTile({
    required this.item,
    required this.etat,
    required this.demarrer,
  });

  final PlanningItem item;
  final EtatVisite etat;
  final bool demarrer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = item.client;
    final actif = etat == EtatVisite.enCours;
    final titre = [
      m.enseigne,
      m.ville,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' – ');
    final detail = [
      DateFormat('HH:mm').format(item.datePassage),
      if (item.raison != null && item.raison!.isNotEmpty) item.raison!,
    ].join(' · ');
    final peutOuvrir = etat != EtatVisite.realisee;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: actif ? SpacePalette.sales.accent : const Color(0xFFE8EAF2),
          width: actif ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: peutOuvrir ? () => _ouvrir(context, ref) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: etat.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(etat.icon, color: etat.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: StatusColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Puce(label: etat.label, color: etat.color),
                ],
              ),
            ),
          ),
          if (actif || demarrer)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FilledButton(
                onPressed: () => _ouvrir(context, ref),
                child: Text(
                  actif ? 'Reprendre la visite' : 'Démarrer la visite',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _ouvrir(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final id = await ref
        .read(visiteServiceProvider)
        .startOrResume(
          userId: userId,
          clientId: item.client.id,
          libelle: item.client.enseigne,
          planningId: item.id,
        );
    if (context.mounted) context.push('/visite/$id');
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

/// Brouillons à terminer, avec un signal pour ceux de plus de 7 jours (jamais supprimés sans confirmation).
class _Brouillons extends StatelessWidget {
  const _Brouillons({required this.drafts});

  final List<VisiteDraft> drafts;

  @override
  Widget build(BuildContext context) {
    final list = drafts.where((d) => d.state == VisiteState.brouillon).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visites à terminer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final d in list)
            Card(
              child: ListTile(
                onTap: () => context.push('/visite/${d.id}'),
                leading: const Icon(Icons.edit_note),
                title: Text(d.libelle.isEmpty ? 'Visite' : d.libelle),
                subtitle: Text(
                  _ancien(d)
                      ? 'Brouillon de plus de 7 jours — terminez-le ou abandonnez-le'
                      : 'Brouillon du ${DateFormat('dd/MM à HH:mm').format(d.updatedAt)}',
                ),
                trailing: _ancien(d)
                    ? const Icon(Icons.warning_amber, color: StatusColors.warn)
                    : const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }

  bool _ancien(VisiteDraft d) =>
      DateTime.now().difference(d.updatedAt) > AppConfig.staleDraftAfter;
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 36, color: StatusColors.muted),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}
