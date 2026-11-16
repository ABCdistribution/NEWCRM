/// Dates en français et repères temporels figés de la démo (« mer. 4 nov. 2026, 14:23 »).
library;

/// Jours ouvrés de la semaine du planning (index 0 = lundi).
const List<String> joursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

/// Mois abrégés (`MOIS`).
const List<String> moisCourts = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Repères temporels de l'application.
///
/// En démonstration tout se passe le mercredi 4 novembre 2026, semaine 45 (maquette figée). Connecté au CRM
/// ([reel] vrai), les repères suivent la vraie date du jour.
class DemoTemps {
  const DemoTemps._();

  /// Vrai quand l'utilisateur est connecté au CRM : la date du jour est la vraie.
  static bool reel = false;

  /// Horloge (remplaçable dans les tests).
  static DateTime Function() maintenant = DateTime.now;

  static final DateTime _demo = DateTime(2026, 11, 4);
  static const List<String> _joursLongs = [
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ];

  /// Jour courant, à minuit.
  static DateTime get aujourdhui {
    if (!reel) return _demo;
    final n = maintenant();
    return DateTime(n.year, n.month, n.day);
  }

  /// « mer. 4 nov. ».
  static String get dateLibelle =>
      '${_joursLongs[aujourdhui.weekday - 1]} $jourCourt';

  /// « 4 nov. » : début de la date texte des visites et commandes du jour.
  static String get jourCourt =>
      '${aujourdhui.day} ${moisCourts[aujourdhui.month - 1]}';

  /// « 4 nov. 14:23 » (démo : heure figée).
  static String get maintenantCourt => reel
      ? '$jourCourt ${deuxChiffres(maintenant().hour)}:${deuxChiffres(maintenant().minute)}'
      : '4 nov. 14:23';

  /// « 04/11/2026 14h23 » (démo : heure figée).
  static String horodatageMaintenant() {
    if (!reel) return horodatage(4, 'nov', 14, 23);
    final n = maintenant();
    return '${deuxChiffres(n.day)}/${deuxChiffres(n.month)}/${n.year} ${deuxChiffres(n.hour)}h${deuxChiffres(n.minute)}';
  }

  static const String heure = '14:23';

  /// « ven. 6 nov. » pour une date.
  static String libelleJour(DateTime d) =>
      '${_joursLongs[d.weekday - 1]} ${d.day} ${moisCourts[d.month - 1]}';

  /// Jour de la semaine courante, 0 = lundi : « mar. 3 nov. ».
  static String jourDeLaSemaine(int i) =>
      libelleJour(DateTime(lundi.year, lundi.month, lundi.day + i));

  /// « lun. 2 nov. » : lundi de la semaine courante.
  static String get lundiLibelle => libelleJour(lundi);

  /// « lun. 9 nov. » : lundi suivant, où la semaine est validée automatiquement.
  static String get lundiSuivantLibelle =>
      libelleJour(DateTime(lundi.year, lundi.month, lundi.day + 7));

  /// Livraison prévue par défaut : deux jours ouvrés après aujourd'hui (démo : « ven. 6 nov. »).
  static String get livraisonPrevue {
    var d = aujourdhui;
    var restants = 2;
    while (restants > 0) {
      d = DateTime(d.year, d.month, d.day + 1);
      if (d.weekday <= 5) restants--;
    }
    return libelleJour(d);
  }

  /// Lundi de la semaine courante.
  static DateTime get lundi {
    final j = aujourdhui;
    return DateTime(j.year, j.month, j.day - (j.weekday - 1));
  }

  /// Index du jour courant dans le planning (0 = lundi) ; samedi et dimanche : vendredi.
  static int get jourPlanning =>
      reel ? (aujourdhui.weekday - 1).clamp(0, 4) : 2;

  /// Numéro de la semaine courante (ISO ; démo : 45).
  static int get semaineCourante => reel ? numeroSemaine(lundi) : 45;

  /// « 2 – 6 novembre » : jours ouvrés de la semaine courante.
  static String get semaineLibelle {
    if (!reel) return '2 – 6 novembre';
    final a = lundi;
    final b = DateTime(a.year, a.month, a.day + 4);
    const mois = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return a.month == b.month
        ? '${a.day} – ${b.day} ${mois[b.month - 1]}'
        : '${a.day} ${mois[a.month - 1]} – ${b.day} ${mois[b.month - 1]}';
  }

  /// Numéro de semaine ISO 8601 d'une date.
  static int numeroSemaine(DateTime d) {
    final jeudi = DateTime.utc(d.year, d.month, d.day - (d.weekday - 4));
    final debut = DateTime.utc(jeudi.year, 1, 1);
    return (jeudi.difference(debut).inDays ~/ 7) + 1;
  }
}

/// Deux chiffres minimum (`p2`).
String deuxChiffres(int n) => n.toString().padLeft(2, '0');

/// Horodatage d'étape de visite (`stampDe`) : « 04/11/2026 08h30 ». `mois` vaut « nov » ou « oct ».
String horodatage(int jour, String mois, int heure, int minute) =>
    '${deuxChiffres(jour)}/${mois == 'nov' ? '11' : '10'}/2026 ${deuxChiffres(heure)}h${deuxChiffres(minute)}';

/// Date d'un texte commençant par « 4 nov. » : la plus récente qui ne soit pas dans le futur, ou nulle.
DateTime? _dateDuTexte(String texte) {
  final m = RegExp(r'^\s*(\d{1,2}) ([a-zéû.]+)').firstMatch(texte);
  if (m == null) return null;
  final jour = int.parse(m.group(1)!);
  final mois = moisCourts.indexOf(m.group(2)!);
  if (mois < 0 || jour == 0) return null;
  final auj = DemoTemps.aujourdhui;
  var d = DateTime(auj.year, mois + 1, jour);
  if (d.isAfter(auj)) d = DateTime(auj.year - 1, mois + 1, jour);
  return d;
}

/// Ancienneté en jours d'une date texte « 4 nov. 08:30 » (`ageTexte`) ; 99 si illisible.
int ageDepuisTexte(String texte) {
  final d = _dateDuTexte(texte);
  return d == null ? 99 : DemoTemps.aujourdhui.difference(d).inDays;
}

/// Jours écoulés depuis une date de timeline (« 29 oct. », « 3 nov. »), à la date du jour ;
/// nul si la date n'est pas passée ou illisible (« auj. », « ven. 6 nov. »). Maquette : `joursDepuisTl`.
int? joursDepuisTimeline(String d) {
  final date = _dateDuTexte(d);
  if (date == null) return null;
  final age = DemoTemps.aujourdhui.difference(date).inDays;
  return age >= 0 ? age : null;
}

/// « 2026-11-16 » → « 16 nov. » (`dateFr`).
String dateFr(String iso) =>
    '${int.parse(iso.substring(8, 10))} ${moisCourts[int.parse(iso.substring(5, 7)) - 1]}';

/// Semaine du planning décalée de `off` semaines par rapport à la semaine 45 (`semaineInfo`).
class SemaineInfo {
  const SemaineInfo({
    required this.num,
    required this.dates,
    required this.mois,
    required this.libelle,
  });

  final int num;

  /// Numéro du jour du mois pour chaque jour ouvré.
  final List<int> dates;

  /// Mois abrégé de chaque jour ouvré.
  final List<String> mois;

  /// « 2 – 6 nov. » ou « 30 nov. – 4 déc. ».
  final String libelle;
}

SemaineInfo semaineInfo(int off) {
  final lundi = DemoTemps.lundi;
  final jours = List.generate(
    5,
    (i) => DateTime(lundi.year, lundi.month, lundi.day + 7 * off + i),
  );
  final a = jours.first;
  final b = jours.last;
  final libelle = a.month == b.month
      ? '${a.day} – ${b.day} ${moisCourts[b.month - 1]}'
      : '${a.day} ${moisCourts[a.month - 1]} – ${b.day} ${moisCourts[b.month - 1]}';
  return SemaineInfo(
    num: DemoTemps.numeroSemaine(jours.first),
    dates: jours.map((d) => d.day).toList(),
    mois: jours.map((d) => moisCourts[d.month - 1]).toList(),
    libelle: libelle,
  );
}
