import '../logic/dates.dart';
import '../models/models.dart';

/// Contact et historique d'un prospect du CRM (`GET /prospects/:id` et `/prospects/:id/historique`).
class DetailProspect {
  const DetailProspect({
    this.contact,
    required this.timeline,
    this.telephone,
    this.mail,
    this.adresse,
  });

  /// Premier contact de la fiche (nom, poste), nul s'il n'y en a pas.
  final String? contact;

  /// Événements du plus récent au plus ancien.
  final List<EvenementProspect> timeline;

  /// Téléphone et e-mail de la fiche (à défaut, ceux du premier contact qui en a un), nuls s'ils manquent.
  final String? telephone;
  final String? mail;

  /// Adresse postale complète de la fiche (rue, code postal, ville), nulle si elle manque.
  final String? adresse;
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String _jour(DateTime? d) =>
    d == null ? '' : '${d.day} ${moisCourts[d.month - 1]}';

String? _auteur(Object? v) => v is Map ? _texte(v['displayName']) : null;

String _joindre(Iterable<String?> morceaux) =>
    morceaux.whereType<String>().where((s) => s.isNotEmpty).join(' · ');

const _bleu = 0xFF2563EB;
const _vert = 0xFF16A34A;
const _orange = 0xFFD97706;
const _violet = 0xFF6545C5;

String _libelleEtape(Object? code) {
  final c = _texte(code);
  if (c == null) return '';
  return StatutProspect.values
      .firstWhere((s) => s.code == c, orElse: () => StatutProspect.nouveau)
      .libelle;
}

/// Événement de timeline à partir d'une ligne de l'historique de l'API ; null si le type est inconnu.
EvenementProspect? evenementDepuisJson(Map<String, dynamic> j) {
  final date = _jour(_date(j['date']));
  switch (j['type']) {
    case 'VISITE':
      final v = j['visite'];
      if (v is! Map<String, dynamic>) return null;
      return EvenementProspect(
        icone: IconeEvenement.pin,
        couleur: _bleu,
        titre: 'Visite',
        date: date,
        detail: _joindre([
          _auteur(v['promoteur']),
          _texte(v['motif']),
          _texte(v['pmcCommentaire']),
        ]),
      );
    case 'OPPORTUNITE':
      final o = j['opportunite'];
      if (o is! Map<String, dynamic>) return null;
      return EvenementProspect(
        icone: IconeEvenement.doc,
        couleur: _violet,
        titre: 'Opportunité',
        date: date,
        detail: _joindre([_texte(o['libelle']), _texte(o['statut'])]),
      );
    case 'APPEL':
      final a = j['appel'];
      if (a is! Map<String, dynamic>) return null;
      return EvenementProspect(
        icone: IconeEvenement.tel,
        couleur: _vert,
        titre: 'Appel',
        date: date,
        detail: _joindre([
          _auteur(a['auteur']),
          _texte(a['resultat']),
          _texte(a['commentaire']),
        ]),
      );
    case 'EMAIL':
      final m = j['email'];
      if (m is! Map<String, dynamic>) return null;
      return EvenementProspect(
        icone: IconeEvenement.doc,
        couleur: _bleu,
        titre: 'E-mail',
        date: date,
        detail: _joindre([_texte(m['sujet']), _texte(m['commentaire'])]),
      );
    case 'ETAPE':
      final e = j['etape'];
      if (e is! Map<String, dynamic>) return null;
      final vers = _libelleEtape(e['vers']);
      final de = _libelleEtape(e['de']);
      return EvenementProspect(
        icone: IconeEvenement.doc,
        couleur: _orange,
        titre: 'Étape → $vers',
        date: date,
        detail: de.isEmpty
            ? _joindre([_auteur(e['auteur']), _texte(e['commentaire'])])
            : _joindre([
                'Passé de « $de » à « $vers »',
                _texte(e['commentaire']),
              ]),
      );
    case 'NOTE':
      final n = j['note'];
      if (n is! Map<String, dynamic>) return null;
      return EvenementProspect(
        icone: IconeEvenement.plus,
        couleur: _orange,
        titre: 'Note',
        date: date,
        detail: _joindre([_texte(n['remarque']), _auteur(n['auteur'])]),
      );
  }
  return null;
}

/// Détail à partir des deux réponses de l'API (`detail` : la fiche, `historique` : `{data: [...]}`).
DetailProspect detailProspectDepuisJson(
  Map<String, dynamic> detail,
  Map<String, dynamic>? historique,
) {
  String? contact;
  String? telContact;
  String? mailContact;
  final contacts = detail['contacts'];
  if (contacts is List) {
    for (final c in contacts) {
      if (c is! Map<String, dynamic>) continue;
      telContact ??= _texte(c['portable']) ?? _texte(c['fixe']);
      mailContact ??= _texte(c['mail']);
      final nom = [
        _texte(c['prenom']),
        _texte(c['nom']),
      ].whereType<String>().join(' ');
      if (nom.isEmpty) continue;
      final poste = _texte(c['poste']);
      contact ??= poste == null ? nom : '$nom ($poste)';
    }
  }
  final ville = _texte(detail['ville']);
  final adresse = [
    _texte(detail['adresse1']),
    [_texte(detail['codePostal']), ville].whereType<String>().join(' '),
  ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
  return DetailProspect(
    contact: contact,
    telephone: _texte(detail['telephone']) ?? telContact,
    mail: _texte(detail['email']) ?? mailContact,
    adresse: adresse.isEmpty ? null : adresse,
    timeline: [
      if (historique != null && historique['data'] is List)
        for (final l in (historique['data'] as List))
          ?(l is Map<String, dynamic> ? evenementDepuisJson(l) : null),
    ],
  );
}
