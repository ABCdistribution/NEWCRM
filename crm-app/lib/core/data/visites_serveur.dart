import '../logic/logic.dart';
import '../models/models.dart';

/// Visites réelles téléchargées du CRM, séparées entre celles du profil et celles des autres promoteurs de son
/// périmètre (nul en démonstration : les visites de la maquette servent alors).
List<Visite>? _miennes;
List<Visite>? _autres;

void definirVisitesServeur({List<Visite>? miennes, List<Visite>? autres}) {
  _miennes = miennes;
  _autres = autres;
}

List<Visite>? visitesMiennesServeur() => _miennes;

List<Visite>? visitesAutresServeur() => _autres;

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Visite de l'app à partir d'une visite de l'API (`GET /visites`) ; null si elle n'a ni identifiant ni client
/// (visite de prospection : l'app ne la montre pas ici).
///
/// L'API ne donne ni le numéro de visite ni le détail des étapes : le numéro reste à 0, seul le début est horodaté,
/// et le nombre de photos est celui des photos reçues.
Visite? visiteDepuisJson(Map<String, dynamic> j, {String? parNom}) {
  final id = _texte(j['id']);
  final client = j['client'];
  final clientId = client is Map ? _texte(client['id']) : null;
  if (id == null || clientId == null) return null;
  final cree = DateTime.tryParse('${j['createdAt']}')?.toLocal();
  final promoteur = j['promoteur'];
  final par =
      parNom ??
      (promoteur is Map ? _texte(promoteur['displayName']) : null) ??
      '';
  final raison = j['raisonAbsenceCommande'];
  final date = cree == null
      ? '—'
      : '${cree.day} ${moisCourts[cree.month - 1]}. ${deuxChiffres(cree.hour)}:${deuxChiffres(cree.minute)}';
  final stamp = cree == null
      ? ''
      : '${deuxChiffres(cree.day)}/${deuxChiffres(cree.month)}/${cree.year} ${deuxChiffres(cree.hour)}h${deuxChiffres(cree.minute)}';
  final photos = (j['_count'] is Map ? (j['_count'] as Map)['photos'] : null);
  final auj = DemoTemps.aujourdhui;
  return Visite(
    id: id,
    num: 0,
    magasinId: clientId,
    par: par,
    parId: promoteur is Map ? _texte(promoteur['id']) : null,
    etat: EtatVisite.envoyee,
    date: date,
    age: cree == null
        ? 99
        : auj.difference(DateTime(cree.year, cree.month, cree.day)).inDays,
    chrono: {if (stamp.isNotEmpty) EtapeDph.debut: stamp},
    recu: stamp.isEmpty ? null : stamp,
    photos: {if (photos is int && photos > 0) EtapeDph.arrivee: photos},
    raisonAbsence: raison is Map ? (_texte(raison['libelle']) ?? '') : '',
    raisonAbsenceId: raison is Map ? _texte(raison['id']) : null,
  );
}

/// Sépare les lignes de l'API entre les visites de `moi` (identifiant du promoteur connecté) et celles des autres.
({List<Visite> miennes, List<Visite> autres}) visitesDepuisJson(
  List<Map<String, dynamic>> lignes, {
  required String? moiId,
  required String moiNom,
}) {
  final miennes = <Visite>[];
  final autres = <Visite>[];
  for (final j in lignes) {
    final promoteur = j['promoteur'];
    final auteur = promoteur is Map ? _texte(promoteur['id']) : null;
    final propre = moiId != null && auteur == moiId;
    final v = visiteDepuisJson(j, parNom: propre ? moiNom : null);
    if (v == null) continue;
    (propre ? miennes : autres).add(v);
  }
  return (miennes: miennes, autres: autres);
}
