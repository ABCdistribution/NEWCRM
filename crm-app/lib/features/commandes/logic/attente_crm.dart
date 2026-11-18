/// Commandes mises en attente dans le CRM (`/commandes/apk`, statut EN_ATTENTE) : modèle, lecture du JSON de l'API et
/// petites règles pures (tri, consigne de livraison, adresse e-mail, identifiant mobile).
library;

import 'dart:math' as math;

import '../../../core/logic/logic.dart';

/// Motifs d'une consigne « Ne pas livrer avant » (la feuille de saisie les propose, « Autre » en plus).
const List<String> motifsConsigneConnus = ['Impératif', 'Inventaire'];

/// Une ligne d'une commande en attente : l'article (identifiant du CRM), la quantité et le prix affiché à la saisie.
class LigneAttenteCrm {
  const LigneAttenteCrm({
    required this.articleId,
    required this.quantite,
    this.prixIndicatif,
    this.libelle = '',
    this.code = '',
  });

  final String articleId;
  final int quantite;
  final double? prixIndicatif;
  final String libelle;
  final String code;
}

/// Une commande EN_ATTENTE du promoteur, telle que le CRM la garde (détail `GET /commandes/apk/:id`).
class CommandeAttenteCrm {
  const CommandeAttenteCrm({
    required this.id,
    required this.idApk,
    required this.clientId,
    required this.clientNom,
    required this.lignes,
    required this.totalIndicatif,
    this.date,
    this.commentaire = '',
    this.nePasLivrerAvant,
    this.motifNePasLivrerAvant,
    this.consigneHeritee = false,
    this.emailValidation,
    this.emailEnvoyeLe,
    this.clientEmail,
  });

  /// Identifiant du CRM (UUID) : celui des appels `PATCH`, `valider`, `envoyer-mail` et `DELETE`.
  final String id;

  /// Identifiant généré par l'app (4 à 10 caractères), clé d'idempotence de la création.
  final String idApk;
  final String clientId;

  /// « Enseigne – Ville » d'après le CRM, quand le client n'est pas dans le portefeuille local.
  final String clientNom;
  final List<LigneAttenteCrm> lignes;
  final double totalIndicatif;
  final DateTime? date;

  /// Remarque libre de la commande (la ligne de consigne de l'ancien format, s'il y en a une, en est retirée).
  final String commentaire;

  /// Consigne « Ne pas livrer avant » : date `aaaa-mm-jj` et motif (texte, « Autre » déjà résolu) ; nuls sans consigne.
  final String? nePasLivrerAvant;
  final String? motifNePasLivrerAvant;

  /// Vrai si la consigne vient de l'ancien format (première ligne du commentaire) et pas des champs de l'API : le
  /// prochain enregistrement la migre.
  final bool consigneHeritee;
  final String? emailValidation;

  /// Quand la commande a été envoyée par mail au client ; nul si elle ne l'a pas été.
  final DateTime? emailEnvoyeLe;
  final String? clientEmail;

  int get nbLignes => lignes.length;
  bool get envoyee => emailEnvoyeLe != null;
}

double? _nombre(Object? v) => switch (v) {
  num() => v.toDouble(),
  String() => double.tryParse(v),
  _ => null,
};

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// `aaaa-mm-jj` d'une date de l'API (la partie jour si elle arrive avec une heure), ou null.
String? _jour(Object? v) {
  final m = v is String ? RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(v) : null;
  return m?.group(1);
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Commande en attente à partir d'une commande de l'API ; null si elle n'est pas EN_ATTENTE ou sans identifiant.
CommandeAttenteCrm? commandeAttenteDepuisJson(Map<String, dynamic> j) {
  final id = _texte(j['id']);
  if (id == null || j['statut'] != 'EN_ATTENTE') return null;
  final client = j['client'] is Map ? j['client'] as Map : const {};
  final clientId = _texte(client['id']);
  if (clientId == null) return null;
  final lignes = <LigneAttenteCrm>[
    if (j['lignes'] is List)
      for (final l in (j['lignes'] as List).whereType<Map>())
        if (_texte(l['article'] is Map ? (l['article'] as Map)['id'] : null)
            case final articleId?)
          LigneAttenteCrm(
            articleId: articleId,
            quantite: (l['quantite'] as num?)?.toInt() ?? 0,
            prixIndicatif: _nombre(l['prixIndicatif']),
            libelle: _texte((l['article'] as Map)['libelle']) ?? '',
            code: _texte((l['article'] as Map)['codeAs400']) ?? '',
          ),
  ];
  final enseigne = _texte(client['enseigne']) ?? '';
  final ville = _texte(client['ville']) ?? '';
  final total =
      _nombre(j['totalIndicatif']) ??
      lignes.fold<double>(0, (t, l) => t + l.quantite * (l.prixIndicatif ?? 0));
  // Ancien format : la consigne était la première ligne du commentaire. On la relit, et on la retire de la remarque.
  final brut = _texte(j['commentaire']) ?? '';
  final ancien = consigneDepuisCommentaire(brut);
  final date = _jour(j['nePasLivrerAvant']);
  final heritee = date == null && ancien.pas;
  return CommandeAttenteCrm(
    id: id,
    idApk: _texte(j['idCommandeApk']) ?? '',
    clientId: clientId,
    clientNom: ville.isEmpty ? enseigne : '$enseigne – $ville',
    lignes: lignes,
    totalIndicatif: total,
    date: _date(j['dateCommande']),
    commentaire: ancien.note,
    nePasLivrerAvant: heritee ? ancien.dateMin : date,
    motifNePasLivrerAvant: heritee
        ? (ancien.motif.isEmpty ? null : ancien.motif)
        : (date == null ? null : _texte(j['motifNePasLivrerAvant'])),
    consigneHeritee: heritee,
    emailValidation: _texte(j['emailValidation']),
    emailEnvoyeLe: _date(j['emailEnvoyeLe']),
    clientEmail: _texte(client['email']),
  );
}

/// Les commandes en attente de la plus récente à la plus ancienne (sans date : en dernier).
List<CommandeAttenteCrm> trierAttentes(Iterable<CommandeAttenteCrm> liste) {
  final l = liste.toList();
  l.sort((a, b) {
    final da = a.date;
    final db = b.date;
    if (da == null || db == null) {
      if (da == null && db == null) return a.id.compareTo(b.id);
      return da == null ? 1 : -1;
    }
    final c = db.compareTo(da);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return l;
}

/// « 3 nov. 17:40 ».
String libelleDateAttente(DateTime d) =>
    '${d.day} ${moisCourts[d.month - 1]} ${deuxChiffres(d.hour)}:${deuxChiffres(d.minute)}';

// ---- Consigne « Ne pas livrer avant » ---------------------------------------------------------------------------

/// « 16/11 » pour `2026-11-16`.
String libelleJourMois(String iso) =>
    iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : iso;

/// Ancien format : la consigne était la première ligne du commentaire, lisible par l'ADV.

final RegExp _consigne = RegExp(
  r'^⏳ Ne pas livrer avant le (\d{4}-\d{2}-\d{2})(?: · ([^\n]*))?(?:\n|$)',
);

/// Remarque et consigne d'un commentaire à l'ancien format ; sans cette ligne, le commentaire est rendu tel quel.
({String note, bool pas, String dateMin, String motif})
consigneDepuisCommentaire(String commentaire) {
  final m = _consigne.firstMatch(commentaire);
  if (m == null) {
    return (note: commentaire.trim(), pas: false, dateMin: '', motif: '');
  }
  return (
    note: commentaire.substring(m.end).trim(),
    pas: true,
    dateMin: m.group(1)!,
    motif: (m.group(2) ?? '').trim(),
  );
}

// ---- Adresse e-mail et identifiant mobile ------------------------------------------------------------------------

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Format d'une adresse e-mail (le CRM refait la validation).
bool emailValide(String s) =>
    s.trim().length <= 254 && _email.hasMatch(s.trim());

const String _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Identifiant d'une commande saisie sur le mobile : 10 caractères alphanumériques (`idCommandeApk`).
String genererIdApk([math.Random? hasard]) {
  final r = hasard ?? math.Random.secure();
  return List.generate(
    10,
    (_) => _alphabet[r.nextInt(_alphabet.length)],
  ).join();
}

// ---- Copie en mémoire ---------------------------------------------------------------------------------------------

List<CommandeAttenteCrm>? _attentesServeur;

/// Commandes en attente téléchargées du CRM (nul en démonstration : l'attente locale de la maquette sert alors).
void definirAttentesServeur(List<CommandeAttenteCrm>? liste) =>
    _attentesServeur = liste;

List<CommandeAttenteCrm>? attentesServeur() => _attentesServeur;
