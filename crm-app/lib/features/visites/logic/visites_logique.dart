/// Calculs du lot « visites », en fonctions pures : liste filtrée, étapes manquantes, horloge de la démo,
/// lecture des nombres saisis. Maquette : `visitesListe`, `manquants`, `horloge`, `etatTournee`.
library;

import '../../../core/data/referentiels_visite.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../state/filtres_visites.dart';

/// Une ligne de la liste des visites (`miennes` et `autres` de `visitesListe`).
class LigneVisite {
  const LigneVisite({
    required this.id,
    required this.magasinId,
    required this.par,
    required this.date,
    required this.age,
    required this.etat,
    required this.propre,
  });

  final String id;
  final String magasinId;
  final String par;

  /// « 4 nov. 08:30 ».
  final String date;

  /// Jours écoulés depuis la visite.
  final int age;
  final EtatVisite etat;

  /// Vrai pour une visite du profil (ouverture normale), faux pour celle d'un autre (compte rendu en lecture seule).
  final bool propre;
}

/// Visites affichées par l'onglet « Visites » selon les filtres (`visitesListe`) : celles du profil, puis celles des
/// autres promoteurs sur les clients visibles.
List<LigneVisite> visitesFiltrees(CrmEtat e, FiltresVisites f) {
  final me = e.nomProfil;
  final miennes = [
    for (final v in e.visites)
      LigneVisite(
        id: v.id,
        magasinId: v.magasinId,
        par: me,
        date: v.date,
        age: 0,
        etat: v.etat,
        propre: true,
      ),
  ];
  final autres = [
    for (final v in e.visitesAutresVisibles)
      LigneVisite(
        id: v.id,
        magasinId: v.magasinId,
        par: v.par,
        date: v.date,
        age: v.age,
        etat: v.etat,
        propre: v.par == me,
      ),
  ];
  final q = f.q.toLowerCase();
  bool garde(LigneVisite v) {
    if (f.portee != PorteeVisites.toutes && !v.propre) return false;
    if (f.etat != null && v.etat != f.etat) return false;
    if (f.periode == PeriodeVisites.jour && v.age != 0) return false;
    if (f.periode == PeriodeVisites.semaine && v.age > 7) return false;
    if (q.isEmpty) return true;
    final nom = e.magasinParId(v.magasinId)?.nom ?? '';
    return '$nom ${v.par}'.toLowerCase().contains(q);
  }

  return [...miennes, ...autres].where(garde).toList();
}

/// Ce que le parcours exige pour passer l'étape `e` avec « Suivant » (nul si rien ne manque) : une photo d'arrivée et
/// une photo du rayon, la réponse à « une commande à mettre en rayon ? », une commande liée ou une raison d'absence
/// (quand le CRM en propose), les questions obligatoires du questionnaire. Les autres étapes n'ont pas d'exigence.
String? erreurEtape(
  Visite v,
  EtapeDph e, {
  List<QuestionFin> questions = const [],
  bool raisonsDisponibles = false,
}) {
  switch (e) {
    case EtapeDph.arrivee:
      if ((v.photos[e] ?? 0) == 0) return "Prenez la photo d'arrivée sur site.";
    case EtapeDph.rayonArrivee:
      if ((v.photos[e] ?? 0) == 0) return 'Prenez la photo du rayon.';
    case EtapeDph.colis:
      if (v.commandeEnRayon == null) {
        return "Indiquez s'il y a une commande à mettre en rayon.";
      }
    case EtapeDph.commande:
      if (v.cmd == null && v.raisonAbsence.isEmpty && raisonsDisponibles) {
        return "Prenez la commande, ou choisissez la raison de l'absence de commande.";
      }
    case EtapeDph.questionnaire:
      final manque = questions.any(
        (q) => q.obligatoire && (v.reponses[q.id] ?? '').isEmpty,
      );
      if (manque) return 'Répondez aux questions obligatoires.';
    default:
      break;
  }
  return null;
}

/// Ce qu'il reste à faire avant de pouvoir terminer la visite : les messages de toutes les étapes du parcours.
List<String> manquants(
  Visite v, {
  List<QuestionFin> questions = const [],
  bool raisonsDisponibles = false,
}) => [
  for (final e in EtapeDph.parcours)
    ?erreurEtape(
      v,
      e,
      questions: questions,
      raisonsDisponibles: raisonsDisponibles,
    ),
];

/// Prochain horodatage de l'horloge de la démo (`horloge`) pour une visite : à partir de 14:23, chaque étape
/// horodatée avance l'heure de 4, 5, 4, 5… minutes (`S.min += 4 + S.min % 3`). Le nombre d'horodatages déjà
/// pris se lit dans la visite : toutes ses étapes faites sauf le début, qui est fixé à la création.
String prochainHorodatage(Visite v) {
  var min = 0;
  for (var i = 0; i < v.chrono.length; i++) {
    min += 4 + min % 3;
  }
  if (DemoTemps.reel) return DemoTemps.horodatageMaintenant();
  final t = 14 * 60 + 23 + min;
  return horodatage(4, 'nov', (t ~/ 60) % 24, t % 60);
}

/// Vrai s'il reste un client de la tournée du jour sans visite du 4 nov. (`etatTournee` = « à faire »).
bool tourneeRestante(CrmEtat e) {
  for (final t in e.tournee) {
    final faite = e.visites.any(
      (v) =>
          v.magasinId == t.magasinId && v.date.startsWith(DemoTemps.jourCourt),
    );
    if (!faite) return true;
  }
  return false;
}

/// Nombre à la façon de `String(n)` de JavaScript puis virgule décimale : 3 → « 3 », 1.5 → « 1,5 ».
String nombreFr(num n) {
  final texte = n == n.roundToDouble() ? n.round().toString() : n.toString();
  return texte.replaceAll('.', ',');
}

/// Lit un décimal saisi comme `parseFloat(texte.replace(',', '.'))` : le plus long préfixe numérique, sinon nul.
double? lireDecimal(String texte) {
  final m = RegExp(
    r'^\s*[+-]?(\d+\.?\d*|\.\d+)',
  ).firstMatch(texte.replaceAll(',', '.'));
  return m == null ? null : double.tryParse(m.group(0)!.trim());
}

/// Lit un entier en ignorant tout ce qui n'est pas un chiffre (`parseInt(texte.replace(/\D/g, ''), 10)`).
int? lireEntierKm(String texte) =>
    int.tryParse(texte.replaceAll(RegExp(r'\D'), ''));

/// Entier avec une espace entre les milliers (« 48 215 »), comme `toLocaleString('fr-FR')` dont la fine insécable
/// est remplacée par une espace ordinaire pour le kilométrage.
String milliersEspaces(int n) => groupeMilliers(n, separateur: ' ');

/// Pluriel de la maquette : « kit », « kits » (s'ajoute dès 2).
String sPluriel(int n) => n > 1 ? 's' : '';

/// Code de colis lu ou saisi : sans espaces autour, nul s'il est vide ou trop long pour être une étiquette.
String? codeColisValide(String? brut) {
  final c = brut?.trim();
  if (c == null || c.isEmpty || c.length > 64) return null;
  return c;
}
