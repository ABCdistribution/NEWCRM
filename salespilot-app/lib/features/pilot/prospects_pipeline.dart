import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_transport.dart';

/// Les quatre colonnes du pipeline de prospection affichées par l'application. Regroupement des étapes du serveur
/// (à valider avec le métier) : à contacter = NOUVEAU + CONTACTE · RDV pris = VISITE · en négo = PROPOSITION +
/// NEGOCIATION · référencé = GAGNE. Les prospects perdus ne sont pas comptés.
enum GroupeProspect {
  aContacter('À contacter'),
  rdvPris('RDV pris'),
  enNego('En négo'),
  reference('Référencé');

  const GroupeProspect(this.libelle);

  final String libelle;

  static GroupeProspect? de(String statut) => switch (statut) {
        'NOUVEAU' || 'CONTACTE' => aContacter,
        'VISITE' => rdvPris,
        'PROPOSITION' || 'NEGOCIATION' => enNego,
        'GAGNE' => reference,
        _ => null,
      };
}

/// Un prospect du pipeline, tel que `GET /prospects/pipeline` le renvoie (périmètre appliqué par l'API).
class ProspectPipeline {
  const ProspectPipeline({
    required this.id,
    required this.enseigne,
    required this.groupe,
    this.ville,
    this.potentiel,
    this.niveauClass,
    this.enAttente = false,
  });

  /// Prospect saisi sur le téléphone, pas encore confirmé par le serveur.
  final bool enAttente;

  final String id;
  final String enseigne;
  final String? ville;
  final GroupeProspect groupe;

  /// Chiffre d'affaires annuel potentiel, en euros.
  final double? potentiel;
  final String? niveauClass;

  /// Aplati à partir des colonnes du pipeline ; les prospects hors des quatre groupes (perdus) sont écartés.
  static List<ProspectPipeline> depuisPipeline(Map<String, dynamic> j) {
    final liste = <ProspectPipeline>[];
    for (final colonne in ((j['etapes'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      final groupe = GroupeProspect.de(colonne['statut'] as String? ?? '');
      if (groupe == null) continue;
      for (final p in ((colonne['prospects'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        final enseigne = (p['enseigne'] as String?)?.trim() ?? '';
        liste.add(ProspectPipeline(
          id: p['id'] as String,
          enseigne: enseigne.isNotEmpty ? enseigne : ((p['raisonSociale'] as String?) ?? 'Sans nom'),
          ville: p['ville'] as String?,
          groupe: groupe,
          potentiel: p['potentielCaAnnuel'] == null ? null : double.tryParse('${p['potentielCaAnnuel']}'),
          niveauClass: p['niveauClass'] as String?,
        ));
      }
    }
    return liste;
  }
}

/// Prospect créé sur le téléphone et pas encore envoyé : la charge utile de la file porte les champs de la fiche.
ProspectPipeline? prospectDepuisOutbox(OutboxItem item) {
  final p = jsonDecode(item.payload) as Map<String, dynamic>;
  final groupe = GroupeProspect.de(p['statut'] as String? ?? 'NOUVEAU');
  if (groupe == null) return null;
  return ProspectPipeline(
    id: item.idApk,
    enseigne: p['enseigne'] as String? ?? 'Sans nom',
    ville: p['ville'] as String?,
    groupe: groupe,
    potentiel: p['potentielCaAnnuel'] == null ? null : double.tryParse('${p['potentielCaAnnuel']}'),
    niveauClass: p['niveauClass'] as String?,
    enAttente: true,
  );
}

/// Prospects saisis sur le téléphone et pas encore confirmés (se met à jour avec la file d'envoi).
final prospectsEnAttenteProvider = StreamProvider.autoDispose<List<ProspectPipeline>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(outboxRepositoryProvider).watchUnsent(userId).map(
        (items) => [
          for (final i in items)
            if (i.kind == OutboxKind.prospect) ?prospectDepuisOutbox(i),
        ],
      );
});

/// Secteur proposable à la création d'un prospect.
class SecteurChoix {
  const SecteurChoix({required this.id, required this.nom, required this.code});
  final String id;
  final String nom;
  final String code;
}

List<SecteurChoix> _secteurs(Object? brut) => [
      for (final s in (brut as List).cast<Map<String, dynamic>>())
        SecteurChoix(id: s['id'] as String, nom: s['nom'] as String, code: s['code'] as String? ?? ''),
    ];

/// Lit les secteurs proposables (périmètre du rôle) sur le serveur et les garde sur le téléphone.
Future<List<SecteurChoix>> chargerSecteursProspectReseau(Ref ref, String userId) async {
  final res = await ref.read(dioProvider).get<List<dynamic>>('/prospects/secteurs');
  final brut = (res.data ?? const []).cast<Map<String, dynamic>>();
  await ref.read(cacheRepositoryProvider).put(userId, 'secteurs-prospect', brut);
  return _secteurs(brut);
}

/// Secteurs du formulaire « Nouveau prospect » : copie locale d'abord (utilisable hors ligne).
final secteursProspectProvider = FutureProvider.autoDispose<List<SecteurChoix>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final cached = await ref.read(cacheRepositoryProvider).get(userId, 'secteurs-prospect');
  if (cached != null) return _secteurs(cached.value);
  try {
    return await chargerSecteursProspectReseau(ref, userId);
  } on Object {
    return const [];
  }
});

/// Plus gros potentiel d'abord ; sans potentiel renseigné, en dernier.
int parPotentiel(ProspectPipeline a, ProspectPipeline b) => (b.potentiel ?? -1).compareTo(a.potentiel ?? -1);

/// « 42 k€/an », « 950 €/an » ou « — » quand le potentiel n'est pas renseigné.
String potentielCourt(double? euros) {
  if (euros == null) return '—';
  return euros >= 1000 ? '${(euros / 1000).round()} k€/an' : '${euros.round()} €/an';
}

/// Lit le pipeline sur le serveur et met la copie locale à jour : la liste des prospects ET les compteurs de
/// l'ancien planning (même requête). Lève une erreur sans réseau.
Future<List<ProspectPipeline>> chargerProspectsReseau(Ref ref, String userId) async {
  final res = await ref.read(dioProvider).get<Map<String, dynamic>>('/prospects/pipeline');
  final brut = <String, dynamic>{
    'etapes': [
      for (final e in ((res.data?['etapes'] as List?) ?? const []).cast<Map<String, dynamic>>())
        {
          'statut': e['statut'],
          'total': e['total'],
          'prospects': [
            for (final p in ((e['prospects'] as List?) ?? const []).cast<Map<String, dynamic>>())
              {
                'id': p['id'],
                'enseigne': p['enseigne'],
                'raisonSociale': p['raisonSociale'],
                'ville': p['ville'],
                'potentielCaAnnuel': p['potentielCaAnnuel'],
                'niveauClass': p['niveauClass'],
              },
          ],
        },
    ],
  };
  await ref.read(cacheRepositoryProvider).put(userId, 'pipeline-prospects', brut);
  return ProspectPipeline.depuisPipeline(brut);
}

/// Prospects du pipeline : copie locale d'abord, réseau seulement au tout premier chargement.
final prospectsPipelineProvider = FutureProvider.autoDispose<List<ProspectPipeline>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final cached = await ref.read(cacheRepositoryProvider).get(userId, 'pipeline-prospects');
  if (cached != null) return ProspectPipeline.depuisPipeline(Map<String, dynamic>.from(cached.value as Map));
  try {
    return await chargerProspectsReseau(ref, userId);
  } on Object {
    return const [];
  }
});
