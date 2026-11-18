import '../logic/logic.dart';
import '../models/models.dart';
import 'commandes_serveur.dart';

/// Contact d'un client (`GET /clients/:id`).
class ContactClient {
  const ContactClient({
    required this.nom,
    this.poste,
    this.telephone,
    this.mail,
  });

  final String nom;
  final String? poste;
  final String? telephone;
  final String? mail;
}

/// Note laissée sur un client.
class NoteClient {
  const NoteClient({required this.texte, this.auteur, required this.date});

  final String texte;
  final String? auteur;
  final String date;
}

/// Visite passée chez un client, en résumé.
class VisiteClient {
  const VisiteClient({required this.date, this.par, required this.photos});

  final String date;
  final String? par;
  final int photos;
}

/// Ce que le CRM sait d'un client au-delà de la liste : contacts, notes, visites, commandes, CA et coordonnées.
class FicheClient {
  const FicheClient({
    required this.contacts,
    required this.notes,
    required this.visites,
    required this.commandes,
    required this.visitesMois,
    this.ca12Mois,
    this.telephone,
    this.mail,
    this.centrale,
    this.secteur,
    this.commerciaux = const [],
    this.periodicite,
  });

  final List<ContactClient> contacts;
  final List<NoteClient> notes;
  final List<VisiteClient> visites;

  /// Dernières commandes du client (les plus récentes d'abord, annulées exclues).
  final List<Commande> commandes;

  /// Visites du mois en cours parmi les dix dernières.
  final int visitesMois;

  /// CA des douze derniers mois en euros, nul si l'historique manque.
  final double? ca12Mois;
  final String? telephone;
  final String? mail;
  final String? centrale;
  final String? secteur;
  final List<String> commerciaux;
  final String? periodicite;

  Commande? get derniereCommande => commandes.firstOrNull;
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String _jour(DateTime d) => '${d.day} ${moisCourts[d.month - 1]}';

double _somme(List<Object?> l, int de, int a) {
  var t = 0.0;
  for (var i = de; i < a && i < l.length; i++) {
    final v = l[i];
    if (v is num) t += v.toDouble();
  }
  return t;
}

/// « 29,4 k€ » au-dessus de 1 000 €, sinon « 840 € ».
String euroCourt(double n) => n >= 1000
    ? '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} k€'
    : '${n.round()} €';

/// Fiche à partir des deux réponses de l'API : `detail` (`GET /clients/:id`) et `historique`
/// (`GET /clients/:id/historique`, absent pour le marketing).
FicheClient ficheClientDepuisJson(
  String clientId,
  Map<String, dynamic> detail,
  Map<String, dynamic>? historique,
) {
  final contacts = <ContactClient>[];
  for (final c in (detail['contacts'] as List? ?? const [])) {
    if (c is! Map<String, dynamic>) continue;
    final nom = [
      _texte(c['prenom']),
      _texte(c['nom']),
    ].whereType<String>().join(' ');
    if (nom.isEmpty) continue;
    contacts.add(
      ContactClient(
        nom: nom,
        poste: _texte(c['poste']) ?? _texte(c['typePoste']),
        telephone: _texte(c['portable']) ?? _texte(c['fixe']),
        mail: _texte(c['mail']),
      ),
    );
  }
  final notes = <NoteClient>[];
  for (final n in (detail['notes'] as List? ?? const [])) {
    if (n is! Map<String, dynamic>) continue;
    final texte = _texte(n['remarque']);
    if (texte == null) continue;
    final quand = _date(n['createdAt']);
    final auteur = n['auteur'];
    notes.add(
      NoteClient(
        texte: texte,
        auteur: auteur is Map ? _texte(auteur['displayName']) : null,
        date: quand == null ? '' : _jour(quand),
      ),
    );
  }
  final periodicites = detail['periodicites'];
  final periodicite = periodicites is List && periodicites.isNotEmpty
      ? (() {
          final p = periodicites.first;
          final inner = p is Map ? p['periodicite'] : null;
          return inner is Map ? _texte(inner['libelle']) : null;
        })()
      : null;
  final centrale = detail['centrale'];
  final secteur = detail['secteur'];

  final visites = <VisiteClient>[];
  final commandes = <Commande>[];
  var visitesMois = 0;
  double? ca12;
  if (historique != null) {
    final auj = DemoTemps.aujourdhui;
    for (final v in (historique['visites'] as List? ?? const [])) {
      if (v is! Map<String, dynamic>) continue;
      final quand = _date(v['createdAt']);
      if (quand == null) continue;
      if (quand.year == auj.year && quand.month == auj.month) visitesMois++;
      final par = v['promoteur'];
      final photos = v['_count'];
      visites.add(
        VisiteClient(
          date: _jour(quand),
          par: par is Map ? _texte(par['displayName']) : null,
          photos: photos is Map && photos['photos'] is num
              ? (photos['photos'] as num).toInt()
              : 0,
        ),
      );
    }
    for (final c in (historique['commandes'] as List? ?? const [])) {
      if (c is! Map<String, dynamic>) continue;
      final cmd = commandeDepuisJson({
        ...c,
        'client': {'id': clientId},
      });
      if (cmd != null) commandes.add(cmd);
    }
    final ca = historique['ca'];
    if (ca is Map && ca['courbeN'] is List && ca['courbeN1'] is List) {
      final n = ca['courbeN'] as List;
      final n1 = ca['courbeN1'] as List;
      final m = auj.month;
      ca12 = _somme(n, 0, m) + _somme(n1, m, 12);
    }
  }
  return FicheClient(
    contacts: contacts,
    notes: notes,
    visites: visites,
    commandes: commandes,
    visitesMois: visitesMois,
    ca12Mois: ca12,
    telephone: _texte(detail['tel1']) ?? _texte(detail['tel2']),
    mail: _texte(detail['email']),
    centrale: centrale is Map ? _texte(centrale['nom']) : null,
    secteur: secteur is Map ? _texte(secteur['nom']) : null,
    commerciaux: [
      for (final c in (detail['commerciaux'] as List? ?? const []))
        if (c is Map && _texte(c['displayName']) != null)
          _texte(c['displayName'])!,
    ],
    periodicite: periodicite,
  );
}
