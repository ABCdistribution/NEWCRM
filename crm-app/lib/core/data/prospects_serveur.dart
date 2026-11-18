import '../models/models.dart';

/// Prospects réels téléchargés du CRM (nul en démonstration : les prospects de la maquette servent alors).
List<Prospect>? _prospectsServeur;

void definirProspectsServeur(List<Prospect>? prospects) =>
    _prospectsServeur = prospects;

List<Prospect>? prospectsServeur() => _prospectsServeur;

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Nombre de l'API : les montants Prisma (Decimal) arrivent en texte.
double? _nombre(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

/// « CARREFOUR MARKET » → « Carrefour Market » (l'import écrit en majuscules).
String _titre(String s) => s
    .toLowerCase()
    .split(RegExp(r'(?<=[\s\-’\x27])'))
    .map((m) => m.isEmpty ? m : m[0].toUpperCase() + m.substring(1))
    .join()
    .trim();

/// Prospect de l'app à partir d'un prospect de l'API (`GET /prospects`) ; null sans identifiant ni enseigne.
///
/// La liste de l'API ne donne ni contact ni historique : la timeline reste vide, rien n'est inventé.
Prospect? prospectDepuisJson(Map<String, dynamic> j) {
  final id = j['id'];
  final enseigne = _texte(j['enseigne']);
  if (id is! String || enseigne == null) return null;
  final ville = _texte(j['ville']);
  final cp = [
    _texte(j['codePostal']),
    ville == null ? null : _titre(ville),
  ].whereType<String>().join(' ');
  final code = _texte(j['statut']);
  final statut = StatutProspect.values.firstWhere(
    (s) => s.code == code,
    orElse: () => StatutProspect.nouveau,
  );
  final secteur = j['secteur'];
  final responsable = j['assignedTo'];
  final classe = _texte(j['niveauClass'])?.toUpperCase();
  return Prospect(
    id: id,
    nom: _titre(enseigne),
    raison: _texte(j['raisonSociale']) ?? enseigne,
    classe: classe != null && RegExp(r'^[A-G]$').hasMatch(classe)
        ? classe
        : '—',
    cp: cp,
    statut: statut,
    pot: (_nombre(j['potentielCaAnnuel']) ?? 0) / 1000,
    proba: (_nombre(j['probabilite']) ?? statut.probaParDefaut).round(),
    timeline: const [],
    secteurId: secteur is Map ? secteur['id'] as String? : null,
    cs: responsable is Map ? _texte(responsable['displayName']) : null,
  );
}
