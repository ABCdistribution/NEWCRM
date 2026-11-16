/// Calculs du lot « visites », en fonctions pures : liste filtrée, étapes manquantes, horloge de la démo,
/// lecture des nombres saisis. Maquette : `visitesListe`, `manquants`, `horloge`, `etatTournee`.
library;

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

/// Ce qu'il reste à faire avant de pouvoir valider une visite (`manquants`) : les étapes DPH non horodatées,
/// puis la visite PEM si elle n'est ni réalisée ni justifiée.
List<String> manquants(Visite v) {
  final m = [
    for (final e in EtapeDph.values)
      if (!v.etapeFaite(e)) e.libelle,
  ];
  if (v.pem.realisee == null ||
      (v.pem.realisee == false && v.pem.raison.isEmpty)) {
    m.add('Visite PEM (réalisée, ou raison de son absence)');
  }
  return m;
}

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

/// Message d'erreur quand l'étape ne peut pas être enregistrée (`v-etape-ok`), nul si elle le peut.
String? erreurEnregistrement(Visite v, EtapeDph e) {
  switch (e) {
    case EtapeDph.dn:
      if (v.kits.isEmpty) {
        return 'Sélectionnez au moins un kit pour la vérification DN.';
      }
    case EtapeDph.concurrence:
      if (!v.concurrence.aucune && v.concurrence.liste.isEmpty) {
        return 'Ajoutez au moins une marque concurrente, ou cochez « Aucune marque concurrente ».';
      }
    case EtapeDph.bilan:
      if (!v.bilanValide) {
        return 'Validez les objectifs pour enregistrer le bilan.';
      }
    case EtapeDph.promos:
      if (v.promosConformes == null) {
        return 'Indiquez si les promotions sont conformes.';
      }
    default:
      break;
  }
  return null;
}

/// Message affiché une fois l'étape enregistrée (la saisie des promotions sert de cas par défaut, comme la maquette).
String messageEtapeEnregistree(EtapeDph e) => switch (e) {
  EtapeDph.dn => 'Vérification DN enregistrée.',
  EtapeDph.bilan => 'Bilan de visite enregistré.',
  EtapeDph.concurrence => 'Concurrence enregistrée.',
  _ => 'Vérification Promos enregistrée.',
};

/// Fin du libellé du bouton « ✓ Enregistrer … » de la saisie d'une étape.
String objetEnregistrement(EtapeDph e) => switch (e) {
  EtapeDph.dn => 'la vérification DN',
  EtapeDph.concurrence => 'la concurrence',
  EtapeDph.bilan => 'le bilan de visite',
  _ => 'la vérification Promos',
};
