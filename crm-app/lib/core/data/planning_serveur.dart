import '../logic/classes.dart';
import '../logic/dates.dart';
import '../logic/ecarts.dart';
import '../models/models.dart';

/// Planning réel de l'utilisateur, tel que le donne le CRM.
///
/// - Promoteur : ses visites planifiées (`GET /plannings`), lues comme des lignes « client » sans heure.
/// - Encadrement (chef de secteur, directeur régional, direction) : sa tournée personnelle (`GET /tournees/me`).
///
/// Les lignes couvrent une fenêtre de quelques semaines autour de la semaine courante ; `EtapePlanning.sem` est le
/// décalage de la semaine par rapport à la semaine courante (0 = courante). Les lignes du samedi et du dimanche ne
/// sont pas reprises : le planning de l'application n'a que cinq jours.
class PlanningServeur {
  const PlanningServeur({required this.etapes, required this.tournee});

  /// Toutes les lignes de la fenêtre téléchargée.
  final List<EtapePlanning> etapes;

  /// Visites planifiées d'aujourd'hui (promoteur) : « Ma tournée du jour ».
  final List<TourneeVisite> tournee;

  /// Lignes de la semaine courante.
  List<EtapePlanning> get semaineCourante => [
    for (final e in etapes)
      if ((e.sem ?? 0) == 0) e,
  ];
}

PlanningServeur? _planning;

/// Remplace (ou, avec null, retire) le planning réel ; appelé par le chargement depuis la base locale.
void definirPlanningServeur(PlanningServeur? planning) => _planning = planning;

PlanningServeur? planningServeur() => _planning;

/// État de la semaine courante de l'utilisateur (`GET /tournees/semaine`).
class SemaineServeur {
  const SemaineServeur({
    required this.lundi,
    required this.phaseRapport,
    required this.verrouillee,
    required this.valideAuto,
    required this.previsionNonRenseignee,
    this.valideAt,
    this.prevuAt,
  });

  /// Lundi de la semaine, « yyyy-mm-dd ».
  final String lundi;

  /// Faux jusqu'au lundi soir (phase prévision), vrai dès le mardi (phase rapport).
  final bool phaseRapport;

  /// Semaine validée : plus rien n'est modifiable.
  final bool verrouillee;
  final bool valideAuto;
  final bool previsionNonRenseignee;
  final DateTime? valideAt;
  final DateTime? prevuAt;
}

/// Une semaine de « Mes rapports » (`GET /tournees/historique`).
class SemaineHistorique {
  const SemaineHistorique({
    required this.lundi,
    required this.numero,
    required this.valide,
    required this.valideAuto,
    required this.valideAt,
    required this.nbPrevues,
    required this.nbLignes,
    required this.visites,
    required this.rdv,
    required this.pourcentPrevu,
  });

  final String lundi;
  final int numero;
  final bool valide;
  final bool valideAuto;
  final DateTime? valideAt;
  final int? nbPrevues;
  final int nbLignes;
  final int visites;
  final int rdv;
  final int? pourcentPrevu;
}

/// Rapports de l'utilisateur : semaine courante, prévision enregistrée et historique.
class RapportsServeur {
  const RapportsServeur({this.semaine, this.prevue, this.semaines = const []});

  /// Nul quand l'état téléchargé date d'une autre semaine (copie locale ancienne).
  final SemaineServeur? semaine;

  /// Prévision enregistrée de la semaine courante, nulle quand elle n'a pas été renseignée.
  final List<EtapePlanning>? prevue;

  /// Du plus récent au plus ancien, semaine courante comprise.
  final List<SemaineHistorique> semaines;
}

RapportsServeur? _rapports;

void definirRapportsServeur(RapportsServeur? rapports) => _rapports = rapports;

RapportsServeur? rapportsServeur() => _rapports;

// ---- Lecture des réponses de l'API ------------------------------------------------------------------------------

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

bool _vrai(Object? v) => v == true;

/// Jour, décalage de semaine et heure d'une date de l'API (« 2026-11-02T09:30:00.000Z » ou « 2026-11-02 »).
///
/// La date est lue telle quelle (sans conversion de fuseau) : le serveur range l'heure saisie comme si elle était UTC.
/// `jour` va de 0 (lundi) à 6 (dimanche) ; `sem` est le décalage par rapport à la semaine de `lundi`.
({int jour, int sem, String heure})? quand(Object? v, DateTime lundi) {
  if (v is! String || v.length < 10) return null;
  final y = int.tryParse(v.substring(0, 4));
  final m = int.tryParse(v.substring(5, 7));
  final d = int.tryParse(v.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  final date = DateTime.utc(y, m, d);
  final lun = DateTime.utc(lundi.year, lundi.month, lundi.day);
  final ecart = date.difference(lun).inDays;
  final sem = (ecart / 7).floor();
  var heure = v.length >= 16 && v[10] == 'T' ? v.substring(11, 16) : '';
  if (heure == '00:00') heure = '';
  return (jour: ecart - sem * 7, sem: sem, heure: heure);
}

/// « 2026-11-02 » d'un lundi.
String isoJour(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// « Enseigne – Ville » : le titre d'une ligne de planning (comme la maquette : « Carrefour – Rouen »).
String _titre(Object? cible, {String repli = ''}) {
  if (cible is! Map) return repli;
  final enseigne = _texte(cible['enseigne']);
  final ville = _texte(cible['ville']);
  if (enseigne == null) return repli;
  return ville == null ? enseigne : '$enseigne – $ville';
}

/// Ligne de planning à partir d'une étape de tournée (`GET /tournees/me`, `/tournees/user/:id`) ; nulle si elle tombe
/// un samedi ou un dimanche ou si la réponse n'a pas la forme attendue.
EtapePlanning? etapeDepuisTournee(Map<String, dynamic> j, DateTime lundi) {
  final id = _texte(j['id']);
  final q = quand(j['datePassage'], lundi);
  if (id == null || q == null || q.jour > 4) return null;
  final adm = _vrai(j['adm']);
  final client = j['client'];
  final prospect = j['prospect'];
  final CiblePlanning cible;
  String? ref;
  String titre;
  if (adm) {
    cible = CiblePlanning.adm;
    titre = 'Administratif';
  } else if (prospect is Map && _texte(prospect['id']) != null) {
    cible = CiblePlanning.prospect;
    ref = _texte(prospect['id']);
    titre = _titre(prospect);
  } else if (client is Map && _texte(client['id']) != null) {
    cible = CiblePlanning.client;
    ref = _texte(client['id']);
    titre = _titre(client);
  } else {
    cible = CiblePlanning.libre;
    titre = _texte(j['libelle']) ?? _texte(j['adresse']) ?? 'Ligne libre';
  }
  final accompagnement = _vrai(j['accompagnement']);
  final soiree = _vrai(j['soireeEtape']);
  return EtapePlanning(
    id: id,
    jour: q.jour,
    heure: q.heure,
    cible: cible,
    ref: ref,
    titre: titre,
    visite: !adm && (_vrai(j['visiteSimple']) || !accompagnement),
    acc: accompagnement,
    rdv: _vrai(j['rdv']),
    soiree: soiree,
    soireeLieu: soiree ? _texte(j['soireeLieu']) : null,
    soireeAdr: soiree ? _texte(j['soireeAdresse']) : null,
    note: _texte(j['note']) ?? '',
    fait: _vrai(j['fait']),
    sem: q.sem,
    classe: cible == CiblePlanning.client ? _classeDe(client) : '',
  );
}

/// Classe du client d'une réponse de l'API (`client.niveauClass`), vide si absente ou invalide.
String _classeDe(Object? client) =>
    client is Map ? classeValide(_texte(client['niveauClass'])) : '';

/// Ligne de planning à partir d'une visite planifiée d'un promoteur (`GET /plannings`) : un client, un jour, sans heure.
EtapePlanning? etapeDepuisPlanning(Map<String, dynamic> j, DateTime lundi) {
  final id = _texte(j['id']);
  final q = quand(j['datePassage'], lundi);
  final client = j['client'];
  final clientId = client is Map ? _texte(client['id']) : null;
  if (id == null || q == null || q.jour > 4 || clientId == null) return null;
  return EtapePlanning(
    id: id,
    jour: q.jour,
    heure: q.heure,
    cible: CiblePlanning.client,
    ref: clientId,
    titre: _titre(client, repli: 'Client'),
    note: _texte(j['raison']) ?? '',
    fait: _vrai(j['fait']),
    sem: q.sem,
    classe: _classeDe(client),
  );
}

/// Ligne de planning à partir d'une ligne de rapport (`GET /tournees/semaine/prevue`, `/rapports/:userId`) ; nulle si
/// elle tombe un week-end. Les lignes de la prévision n'ont pas d'identifiant : [rapprocherPrevue] leur en donne un.
EtapePlanning? etapeDepuisLigne(
  Map<String, dynamic> j,
  DateTime lundi, {
  required String idRepli,
}) {
  final q = quand(j['jour'], lundi);
  if (q == null || q.jour > 4) return null;
  final heure = _texte(j['heure']) ?? '';
  final adm = _vrai(j['adm']);
  final clientId = _texte(j['clientId']);
  final prospectId = _texte(j['prospectId']);
  final CiblePlanning cible = adm
      ? CiblePlanning.adm
      : prospectId != null
      ? CiblePlanning.prospect
      : clientId != null
      ? CiblePlanning.client
      : CiblePlanning.libre;
  final ville = _texte(j['ville']);
  var titre = _texte(j['titre']) ?? _texte(j['libelle']) ?? '';
  if (adm) {
    titre = 'Administratif';
  } else if (ville != null &&
      cible != CiblePlanning.libre &&
      titre.isNotEmpty) {
    titre = '$titre – $ville';
  } else if (titre.isEmpty) {
    titre = 'Ligne libre';
  }
  final accompagnement = _vrai(j['accompagnement']);
  final soiree = _vrai(j['soireeEtape']);
  return EtapePlanning(
    id: _texte(j['id']) ?? idRepli,
    jour: q.jour,
    heure: heure.isNotEmpty ? heure : q.heure,
    cible: cible,
    ref: prospectId ?? clientId,
    titre: titre,
    visite: !adm && (_vrai(j['visiteSimple']) || !accompagnement),
    acc: accompagnement,
    rdv: _vrai(j['rdv']),
    soiree: soiree,
    soireeLieu: soiree ? _texte(j['soireeLieu']) : null,
    soireeAdr: soiree ? _texte(j['soireeAdresse']) : null,
    note: _texte(j['note']) ?? '',
    fait: _vrai(j['fait']),
    sem: q.sem,
    classe: cible == CiblePlanning.client
        ? classeValide(_texte(j['niveauClass']))
        : '',
  );
}

/// Lignes d'une liste de rapport, sans celles qui tombent un week-end. `prefixe` sert à nommer les lignes sans id.
List<EtapePlanning> lignesDepuisRapport(
  Object? brutes,
  DateTime lundi, {
  String prefixe = 'ligne',
}) {
  if (brutes is! List) return const [];
  final lignes = <EtapePlanning>[];
  for (var i = 0; i < brutes.length; i++) {
    final b = brutes[i];
    if (b is! Map<String, dynamic>) continue;
    final e = etapeDepuisLigne(b, lundi, idRepli: '$prefixe-$i');
    if (e != null) lignes.add(e);
  }
  return lignes;
}

String _cle(EtapePlanning e) =>
    '${e.cible.code}|${e.ref ?? e.titre.toLowerCase()}';

/// Donne à chaque ligne de la prévision l'identifiant de la ligne réalisée qui lui correspond.
///
/// La photographie de la prévision enregistrée par le CRM ne porte pas l'identifiant des étapes : on rapproche donc
/// chaque ligne prévue d'une ligne réalisée visant le même client, prospect ou texte, en préférant le même jour et
/// la même heure, puis le même jour, puis n'importe quel jour (ligne déplacée). Une ligne prévue sans correspondance
/// (retirée du planning) reçoit un identifiant propre : elle apparaît « retirée » dans les écarts.
List<EtapePlanning> rapprocherPrevue(
  List<EtapePlanning> prevue,
  List<EtapePlanning> realisee,
) {
  final pris = <String>{};
  final ids = List<String?>.filled(prevue.length, null);
  bool memeCible(EtapePlanning a, EtapePlanning b) =>
      (a.sem ?? 0) == (b.sem ?? 0) && _cle(a) == _cle(b);
  final criteres = <bool Function(EtapePlanning, EtapePlanning)>[
    (p, r) => memeCible(p, r) && p.jour == r.jour && p.heure == r.heure,
    (p, r) => memeCible(p, r) && p.jour == r.jour,
    memeCible,
  ];
  for (final critere in criteres) {
    for (var i = 0; i < prevue.length; i++) {
      if (ids[i] != null) continue;
      for (final r in realisee) {
        if (!pris.contains(r.id) && critere(prevue[i], r)) {
          ids[i] = r.id;
          pris.add(r.id);
          break;
        }
      }
    }
  }
  return [
    for (var i = 0; i < prevue.length; i++)
      EtapePlanning(
        id: ids[i] ?? 'prevu-$i',
        jour: prevue[i].jour,
        heure: prevue[i].heure,
        cible: prevue[i].cible,
        ref: prevue[i].ref,
        titre: prevue[i].titre,
        visite: prevue[i].visite,
        acc: prevue[i].acc,
        rdv: prevue[i].rdv,
        remp: prevue[i].remp,
        appel: prevue[i].appel,
        soiree: prevue[i].soiree,
        soireeLieu: prevue[i].soireeLieu,
        soireeAdr: prevue[i].soireeAdr,
        note: prevue[i].note,
        fait: false,
        sem: prevue[i].sem,
        classe: prevue[i].classe,
      ),
  ];
}

/// Planning réel à partir des lignes téléchargées et rangées dans la base locale.
///
/// Chaque ligne porte `_src` : « tournee » (étape de tournée) ou « planning » (visite planifiée d'un promoteur).
/// `lundi` est le lundi de la semaine courante.
PlanningServeur planningDepuisJson(
  List<Map<String, dynamic>> lignes,
  DateTime lundi,
) {
  final etapes = <EtapePlanning>[];
  for (final j in lignes) {
    final e = j['_src'] == 'planning'
        ? etapeDepuisPlanning(j, lundi)
        : etapeDepuisTournee(j, lundi);
    if (e != null) etapes.add(e);
  }
  etapes.sort((a, b) {
    final c = (a.sem ?? 0).compareTo(b.sem ?? 0);
    if (c != 0) return c;
    final d = a.jour.compareTo(b.jour);
    return d != 0 ? d : a.heure.compareTo(b.heure);
  });
  // Tournée du jour : les visites planifiées d'aujourd'hui (promoteur), triées comme le planning.
  final jour = DemoTemps.aujourdhui;
  final tournee = <TourneeVisite>[];
  for (final j in lignes) {
    if (j['_src'] != 'planning') continue;
    final q = quand(j['datePassage'], lundi);
    final client = j['client'];
    final id = _texte(j['id']);
    final clientId = client is Map ? _texte(client['id']) : null;
    if (q == null || id == null || clientId == null) continue;
    if (q.sem != 0 || q.jour != _jourDe(jour, lundi)) continue;
    tournee.add(
      TourneeVisite(
        id: id,
        magasinId: clientId,
        heure: q.heure,
        type: 'Planifiée',
      ),
    );
  }
  return PlanningServeur(etapes: etapes, tournee: tournee);
}

/// Index (0 = lundi) du jour de la semaine de `lundi` qui correspond à `aujourdhui` ; -1 hors de la semaine.
int _jourDe(DateTime aujourdhui, DateTime lundi) {
  final a = DateTime.utc(aujourdhui.year, aujourdhui.month, aujourdhui.day);
  final l = DateTime.utc(lundi.year, lundi.month, lundi.day);
  final ecart = a.difference(l).inDays;
  return ecart >= 0 && ecart < 7 ? ecart : -1;
}

SemaineServeur? semaineDepuisJson(Map<String, dynamic> j) {
  final lundi = _texte(j['semaine']);
  if (lundi == null) return null;
  return SemaineServeur(
    lundi: lundi.substring(0, lundi.length < 10 ? lundi.length : 10),
    phaseRapport: j['phase'] == 'RAPPORT',
    verrouillee: _vrai(j['verrouillee']),
    valideAuto: _vrai(j['valideAuto']),
    previsionNonRenseignee: _vrai(j['previsionNonRenseignee']),
    valideAt: DateTime.tryParse('${j['valideAt']}')?.toLocal(),
    prevuAt: DateTime.tryParse('${j['prevuAt']}')?.toLocal(),
  );
}

int? _entierNul(Object? v) => v is num ? v.toInt() : null;

List<SemaineHistorique> historiqueDepuisJson(Object? j) {
  final semaines = j is Map ? j['semaines'] : null;
  if (semaines is! List) return const [];
  final r = <SemaineHistorique>[];
  for (final s in semaines.whereType<Map<String, dynamic>>()) {
    final lundi = _texte(s['semaine']);
    final numero = _entierNul(s['numero']);
    if (lundi == null || numero == null) continue;
    final statut = '${s['statut']}';
    r.add(
      SemaineHistorique(
        lundi: lundi.substring(0, lundi.length < 10 ? lundi.length : 10),
        numero: numero,
        valide: statut == 'VALIDE' || statut == 'VALIDE_AUTO',
        valideAuto: statut == 'VALIDE_AUTO' || _vrai(s['valideAuto']),
        valideAt: DateTime.tryParse('${s['valideAt']}')?.toLocal(),
        nbPrevues: _entierNul(s['nbPrevues']),
        nbLignes: _entierNul(s['nbLignes']) ?? 0,
        visites: _entierNul(s['visites']) ?? 0,
        rdv: _entierNul(s['rdv']) ?? 0,
        pourcentPrevu: _entierNul(s['pourcentPrevu']),
      ),
    );
  }
  return r;
}

/// Rapports à partir de l'objet rangé dans la base locale :
/// `{semaine: <GET /tournees/semaine>, prevue: <GET /tournees/semaine/prevue>, historique: <GET /tournees/historique>}`.
///
/// L'état de la semaine et la prévision ne sont gardés que s'ils concernent la semaine courante (`lundi`) : une copie
/// locale ancienne ne doit pas faire croire qu'une prévision de la semaine dernière est celle de cette semaine.
RapportsServeur rapportsDepuisJson(Map<String, dynamic> j, DateTime lundi) {
  final brute = j['semaine'];
  var semaine = brute is Map<String, dynamic> ? semaineDepuisJson(brute) : null;
  if (semaine != null && semaine.lundi != isoJour(lundi)) semaine = null;
  final prevue = j['prevue'];
  final brutes = prevue is Map ? prevue['prevue'] : prevue;
  return RapportsServeur(
    semaine: semaine,
    prevue: semaine == null || brutes is! List
        ? null
        : lignesDepuisRapport(brutes, lundi, prefixe: 'prevu'),
    semaines: historiqueDepuisJson(j['historique']),
  );
}

/// Fenêtre de dates téléchargée autour de la semaine courante : trois semaines avant, cinq semaines après
/// (`debut` inclus, `fin` exclue, « yyyy-mm-dd »).
({String debut, String fin}) fenetrePlanning(DateTime lundi) => (
  debut: isoJour(DateTime(lundi.year, lundi.month, lundi.day - 21)),
  fin: isoJour(DateTime(lundi.year, lundi.month, lundi.day + 35)),
);

/// Rapport d'activité d'une semaine : prévision enregistrée, tournée réalisée et écarts entre les deux.
///
/// Venu de `GET /rapports/:userId` (consultation d'un chef de secteur ou d'un directeur régional par son encadrement)
/// ou de la tournée de l'utilisateur lui-même (`/tournees/semaine/prevue` et `/tournees/me`).
class RapportEquipe {
  const RapportEquipe({
    required this.lundi,
    required this.valide,
    required this.valideAuto,
    required this.valideAt,
    required this.nonRenseignee,
    required this.prevue,
    required this.realisee,
    required this.ecarts,
  });

  /// Lundi de la semaine.
  final DateTime lundi;
  final bool valide;
  final bool valideAuto;
  final DateTime? valideAt;

  /// Aucune prévision enregistrée : pas de comparaison possible.
  final bool nonRenseignee;

  /// Prévision enregistrée, avec les identifiants des lignes réalisées correspondantes.
  final List<EtapePlanning>? prevue;
  final List<EtapePlanning> realisee;

  /// Comparaison prévu / réalisé ; nulle sans prévision.
  final ResultatEcarts? ecarts;
}

/// Rapport à partir de l'état de la semaine (`etat`, peut manquer), de la prévision et des lignes réalisées.
RapportEquipe rapportDepuisLignes({
  required DateTime lundi,
  required Map<String, dynamic>? etat,
  required Object? prevueBrute,
  required List<EtapePlanning> realisee,
}) {
  final valideAt = etat == null
      ? null
      : DateTime.tryParse('${etat['valideAt']}')?.toLocal();
  final valide =
      valideAt != null || (etat != null && _vrai(etat['verrouillee']));
  final prevue = prevueBrute is List
      ? rapprocherPrevue(
          lignesDepuisRapport(prevueBrute, lundi, prefixe: 'prevu'),
          realisee,
        )
      : null;
  final vide = prevue == null || prevue.isEmpty;
  return RapportEquipe(
    lundi: lundi,
    valide: valide,
    valideAuto: etat != null && _vrai(etat['valideAuto']),
    valideAt: valideAt,
    nonRenseignee: vide,
    prevue: vide ? null : prevue,
    realisee: realisee,
    ecarts: vide
        ? null
        : calculerEcarts(
            prevu: prevue,
            etapes: realisee,
            // Une semaine passée est terminée même si son rapport n'a pas été validé.
            valide: valide || lundi.isBefore(DemoTemps.lundi),
          ),
  );
}

/// Rapport d'un auteur à partir de `GET /rapports/:userId` : `{auteur, etat, prevue, realisee}`.
RapportEquipe? rapportEquipeDepuisJson(Object? brut, DateTime lundi) {
  if (brut is! Map<String, dynamic>) return null;
  final etat = brut['etat'];
  return rapportDepuisLignes(
    lundi: lundi,
    etat: etat is Map<String, dynamic> ? etat : null,
    prevueBrute: brut['prevue'],
    realisee: lignesDepuisRapport(brut['realisee'], lundi, prefixe: 'reel'),
  );
}

/// Rapport de l'utilisateur lui-même pour une semaine passée, à partir de
/// `{semaine: <GET /tournees/semaine>, prevue: <GET /tournees/semaine/prevue>, etapes: <GET /tournees/me>}`.
RapportEquipe? rapportPersonnelDepuisJson(Object? brut, DateTime lundi) {
  if (brut is! Map<String, dynamic>) return null;
  final etapes = brut['etapes'];
  final prevue = brut['prevue'];
  final semaine = brut['semaine'];
  return rapportDepuisLignes(
    lundi: lundi,
    etat: semaine is Map<String, dynamic> ? semaine : null,
    prevueBrute: prevue is Map ? prevue['prevue'] : prevue,
    realisee: [
      if (etapes is List)
        for (final j in etapes.whereType<Map<String, dynamic>>())
          ?etapeDepuisTournee(j, lundi),
    ],
  );
}
