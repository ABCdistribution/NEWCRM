import 'package:dio/dio.dart';

import '../../core/db/cache_repository.dart';

/// État d'un promoteur dans la journée, déduit de son planning (aucune position en direct n'existe côté API).
enum EtatPromoteur { termine, enRetard, enCours, aVenir, sansTournee }

/// Un promoteur de l'équipe : CA du mois et avancement de sa tournée du jour.
class PromoteurEquipe {
  const PromoteurEquipe({
    required this.nom,
    required this.ca,
    required this.visitesFaites,
    required this.visitesPrevues,
    required this.enRetard,
    this.planningConnu = true,
  });

  final String nom;
  final double ca;
  final int visitesFaites;
  final int visitesPrevues;

  /// Une visite prévue à une heure précise est dépassée sans être faite.
  final bool enRetard;

  /// Faux si le planning du promoteur n'a pas pu être lu (réseau) : on n'affiche alors aucun état.
  final bool planningConnu;

  String get prenom => nom.split(' ').firstWhere((s) => s.isNotEmpty, orElse: () => nom);

  EtatPromoteur get etat {
    if (visitesPrevues == 0) return EtatPromoteur.sansTournee;
    if (visitesFaites >= visitesPrevues) return EtatPromoteur.termine;
    if (enRetard) return EtatPromoteur.enRetard;
    return visitesFaites > 0 ? EtatPromoteur.enCours : EtatPromoteur.aVenir;
  }

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'ca': ca,
        'faites': visitesFaites,
        'prevues': visitesPrevues,
        'retard': enRetard,
        'connu': planningConnu,
      };

  factory PromoteurEquipe.fromJson(Map<String, dynamic> j) => PromoteurEquipe(
        nom: j['nom'] as String,
        ca: (j['ca'] as num).toDouble(),
        visitesFaites: (j['faites'] as num).toInt(),
        visitesPrevues: (j['prevues'] as num).toInt(),
        enRetard: j['retard'] as bool,
        planningConnu: (j['connu'] as bool?) ?? true,
      );
}

/// Données de l'accueil ABC Pilot : CA du mois (avec évolution vs N-1) et équipe.
class AccueilPilot {
  const AccueilPilot({required this.caMois, required this.evolutionPct, required this.mois, required this.equipe});

  final double caMois;
  final int? evolutionPct;
  final int mois;
  final List<PromoteurEquipe> equipe;

  int get visitesFaites => equipe.fold(0, (a, p) => a + p.visitesFaites);
  int get visitesPrevues => equipe.fold(0, (a, p) => a + p.visitesPrevues);

  Map<String, dynamic> toJson() => {'ca': caMois, 'evo': evolutionPct, 'mois': mois, 'equipe': equipe.map((p) => p.toJson()).toList()};

  factory AccueilPilot.fromJson(Map<String, dynamic> j) => AccueilPilot(
        caMois: (j['ca'] as num).toDouble(),
        evolutionPct: (j['evo'] as num?)?.toInt(),
        mois: (j['mois'] as num).toInt(),
        equipe: (j['equipe'] as List).map((e) => PromoteurEquipe.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// Accueil Pilot : réseau d'abord, copie locale si le réseau est indisponible. Le périmètre (secteurs du chef de
/// secteur, région, tout) est appliqué par l'API ; l'application ne filtre rien.
class PilotRepository {
  PilotRepository(this._dio, this._cache);

  final Dio _dio;
  final CacheRepository _cache;

  static const _maxPromoteurs = 40; // garde-fou : un appel de planning par promoteur

  Future<Cached<AccueilPilot>> load(String userId, DateTime maintenant) async {
    const key = 'pilot-accueil';
    try {
      final res = await _dio.get<Map<String, dynamic>>('/dashboard/direction', queryParameters: {'annee': maintenant.year, 'mois': maintenant.month});
      final data = res.data ?? const <String, dynamic>{};
      final kpis = (data['kpis'] as Map?) ?? const {};
      final classement = ((data['classement'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where((p) => p['userId'] != null && p['isActive'] != false)
          .take(_maxPromoteurs)
          .toList();

      final debut = DateTime(maintenant.year, maintenant.month, maintenant.day);
      final fin = debut.add(const Duration(days: 1));
      final equipe = await Future.wait(classement.map((p) => _promoteur(p, debut, fin, maintenant)));
      equipe.sort((a, b) => b.ca.compareTo(a.ca));

      final accueil = AccueilPilot(
        caMois: (kpis['ca'] as num?)?.toDouble() ?? 0,
        evolutionPct: (kpis['deltaPct'] as num?)?.toInt(),
        mois: maintenant.month,
        equipe: equipe,
      );
      await _cache.put(userId, key, accueil.toJson());
      return Cached(accueil, DateTime.now());
    } on DioException {
      final cached = await _cache.get(userId, key);
      if (cached == null) rethrow;
      return Cached(AccueilPilot.fromJson(Map<String, dynamic>.from(cached.value as Map)), cached.fetchedAt, fromCache: true);
    }
  }

  Future<PromoteurEquipe> _promoteur(Map<String, dynamic> p, DateTime debut, DateTime fin, DateTime maintenant) async {
    final nom = (p['nom'] as String?) ?? 'Promoteur';
    final ca = (p['ca'] as num?)?.toDouble() ?? 0;
    try {
      final res = await _dio.get<List<dynamic>>('/plannings', queryParameters: {
        'promoteurId': p['userId'],
        'debut': debut.toUtc().toIso8601String(),
        'fin': fin.toUtc().toIso8601String(),
      });
      final lignes = (res.data ?? const []).cast<Map<String, dynamic>>();
      final faites = lignes.where((l) => l['fait'] == true).length;
      // Une heure à 00:00 signifie « jour seulement » : on ne parle de retard que pour une heure précise.
      final retard = lignes.any((l) {
        if (l['fait'] == true) return false;
        final d = DateTime.tryParse((l['datePassage'] as String?) ?? '')?.toLocal();
        return d != null && (d.hour != 0 || d.minute != 0) && d.isBefore(maintenant.subtract(const Duration(minutes: 30)));
      });
      return PromoteurEquipe(nom: nom, ca: ca, visitesFaites: faites, visitesPrevues: lignes.length, enRetard: retard);
    } on DioException {
      return PromoteurEquipe(nom: nom, ca: ca, visitesFaites: 0, visitesPrevues: 0, enRetard: false, planningConnu: false);
    }
  }
}
