/// Journal des appels et e-mails d'un magasin (`GET /clients/:id/journal-contacts`, `{data: [...]}`).
library;

import '../envoi/corps_activite.dart';

/// Nature d'une entrée du journal.
enum TypeContact { appel, email }

/// Un appel ou un e-mail journalisé sur un magasin, avec ce que l'API en donne.
class EntreeJournalContact {
  const EntreeJournalContact({
    required this.type,
    required this.id,
    required this.date,
    this.resultat,
    this.sujet,
    this.auteur,
  });

  final TypeContact type;
  final String id;
  final DateTime date;

  /// Appel seulement : résultat connu de l'application ; nul si absent ou d'une valeur inconnue.
  final ResultatAppel? resultat;

  /// E-mail seulement.
  final String? sujet;
  final String? auteur;
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Entrées de la réponse de l'API, plus récentes en tête ; les lignes illisibles (type, identifiant ou date manquants)
/// sont écartées.
List<EntreeJournalContact> journalContactsDepuisJson(Object? json) {
  final data = json is Map ? json['data'] : null;
  if (data is! List) return const [];
  final liste = <EntreeJournalContact>[];
  for (final e in data) {
    if (e is! Map) continue;
    final type = switch (e['type']) {
      'APPEL' => TypeContact.appel,
      'EMAIL' => TypeContact.email,
      _ => null,
    };
    final id = _texte(e['id']);
    final dateBrute = e['date'];
    final date = dateBrute is String
        ? DateTime.tryParse(dateBrute)?.toLocal()
        : null;
    if (type == null || id == null || date == null) continue;
    final auteur = e['auteur'];
    liste.add(
      EntreeJournalContact(
        type: type,
        id: id,
        date: date,
        resultat: type == TypeContact.appel
            ? ResultatAppel.depuisCode(e['resultat'])
            : null,
        sujet: type == TypeContact.email ? _texte(e['sujet']) : null,
        auteur: auteur is String ? _texte(auteur) : null,
      ),
    );
  }
  liste.sort((a, b) => b.date.compareTo(a.date));
  return liste;
}
