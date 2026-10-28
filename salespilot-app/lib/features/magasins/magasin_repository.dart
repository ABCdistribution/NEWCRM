import 'package:dio/dio.dart';

import '../../core/db/cache_repository.dart';

/// Magasin du portefeuille, avec les indicateurs de `GET /clients?enrich=1`.
class Magasin {
  const Magasin({
    required this.id,
    required this.codeAs400,
    required this.enseigne,
    this.raisonSociale,
    this.ville,
    this.codePostal,
    this.niveauClass,
    this.actif = true,
    this.derniereVisiteJours,
    this.periodicite,
    this.etat,
    this.alertes = 0,
    this.enRetard = false,
  });

  final String id;
  final String codeAs400;
  final String enseigne;
  final String? raisonSociale;
  final String? ville;
  final String? codePostal;
  final String? niveauClass;
  final bool actif;
  final int? derniereVisiteJours;
  final String? periodicite;

  /// ok · attention · alerte
  final String? etat;
  final int alertes;
  final bool enRetard;

  factory Magasin.fromJson(Map<String, dynamic> j) => Magasin(
        id: j['id'] as String,
        codeAs400: (j['codeAs400'] as String?) ?? '',
        enseigne: ((j['enseigne'] as String?) ?? (j['raisonSociale'] as String?) ?? '').trim(),
        raisonSociale: j['raisonSociale'] as String?,
        ville: (j['ville'] as String?)?.trim(),
        codePostal: j['codePostal'] as String?,
        niveauClass: j['niveauClass'] as String?,
        actif: (j['actif'] as bool?) ?? true,
        derniereVisiteJours: (j['derniereVisiteJours'] as num?)?.toInt(),
        periodicite: j['periodicite'] as String?,
        etat: j['etat'] as String?,
        alertes: (j['alertes'] as num?)?.toInt() ?? 0,
        enRetard: (j['enRetard'] as bool?) ?? false,
      );

  String get libelle => ville == null || ville!.isEmpty ? enseigne : '$enseigne — $ville';
}

/// Contact et note d'une fiche magasin.
class ContactMagasin {
  const ContactMagasin({required this.nom, this.poste, this.typePoste, this.fixe, this.portable, this.mail});

  final String nom;
  final String? poste;
  final String? typePoste;
  final String? fixe;
  final String? portable;
  final String? mail;

  factory ContactMagasin.fromJson(Map<String, dynamic> j) => ContactMagasin(
        nom: [j['prenom'], j['nom']].whereType<String>().where((s) => s.trim().isNotEmpty).join(' '),
        poste: j['poste'] as String?,
        typePoste: j['typePoste'] as String?,
        fixe: j['fixe'] as String?,
        portable: j['portable'] as String?,
        mail: j['mail'] as String?,
      );
}

class NoteMagasin {
  const NoteMagasin({required this.remarque, this.date});

  final String remarque;
  final DateTime? date;

  factory NoteMagasin.fromJson(Map<String, dynamic> j) => NoteMagasin(
        remarque: (j['remarque'] as String?) ?? '',
        date: DateTime.tryParse((j['createdAt'] as String?) ?? '')?.toLocal(),
      );
}

class FicheMagasin {
  const FicheMagasin({
    required this.magasin,
    required this.contacts,
    required this.notes,
    this.adresse,
    this.telephone,
    this.latitude,
    this.longitude,
    this.periodicite,
  });

  final Magasin magasin;
  final List<ContactMagasin> contacts;
  final List<NoteMagasin> notes;
  final String? adresse;
  final String? telephone;
  final double? latitude;
  final double? longitude;

  /// Libellé de la périodicité de visite (ex. « 1 fois par mois »).
  final String? periodicite;
}

/// Commande récente du magasin (`GET /clients/:id/historique`).
class CommandeMagasin {
  const CommandeMagasin({required this.numero, required this.total, required this.nbLignes, required this.annulee, this.date});

  final String? numero;
  final double total;
  final int nbLignes;
  final bool annulee;
  final DateTime? date;

  factory CommandeMagasin.fromJson(Map<String, dynamic> j) => CommandeMagasin(
        numero: j['numero']?.toString(),
        total: (j['total'] as num?)?.toDouble() ?? 0,
        nbLignes: (j['nbLignes'] as num?)?.toInt() ?? 0,
        annulee: (j['annulee'] as bool?) ?? false,
        date: DateTime.tryParse((j['dateCommande'] as String?) ?? '')?.toLocal(),
      );
}

/// Visite passée du magasin.
class VisiteMagasin {
  const VisiteMagasin({required this.date, required this.photos, this.promoteur});

  final DateTime? date;
  final int photos;
  final String? promoteur;

  factory VisiteMagasin.fromJson(Map<String, dynamic> j) => VisiteMagasin(
        date: DateTime.tryParse((j['createdAt'] as String?) ?? '')?.toLocal(),
        photos: ((j['_count'] as Map?)?['photos'] as num?)?.toInt() ?? 0,
        promoteur: (j['promoteur'] as Map?)?['displayName'] as String?,
      );
}

/// Historique du magasin : dernières commandes et visites, CA mensuel de l'année N et de N-1.
class HistoriqueMagasin {
  const HistoriqueMagasin({required this.commandes, required this.visites, required this.courbeN, required this.courbeN1});

  final List<CommandeMagasin> commandes;
  final List<VisiteMagasin> visites;
  final List<double> courbeN;
  final List<double> courbeN1;

  factory HistoriqueMagasin.fromJson(Map<String, dynamic> j) {
    List<double> courbe(Object? v) {
      final l = (v as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
      return [...l, ...List<double>.filled(12 - l.length.clamp(0, 12), 0)].take(12).toList();
    }

    final ca = (j['ca'] as Map<String, dynamic>?) ?? const {};
    return HistoriqueMagasin(
      commandes: ((j['commandes'] as List?) ?? const []).map((e) => CommandeMagasin.fromJson(e as Map<String, dynamic>)).toList(),
      visites: ((j['visites'] as List?) ?? const []).map((e) => VisiteMagasin.fromJson(e as Map<String, dynamic>)).toList(),
      courbeN: courbe(ca['courbeN']),
      courbeN1: courbe(ca['courbeN1']),
    );
  }

  /// CA des 12 derniers mois glissants (fin = [maintenant]).
  double ca12Mois(DateTime maintenant) {
    final m = maintenant.month;
    return courbeN.take(m).fold(0.0, (a, b) => a + b) + courbeN1.skip(m).fold(0.0, (a, b) => a + b);
  }

  /// Évolution du CA depuis janvier par rapport à la même période de N-1, en % (null si N-1 est à zéro).
  double? evolutionCumul(DateTime maintenant) {
    final m = maintenant.month;
    final n = courbeN.take(m).fold(0.0, (a, b) => a + b);
    final n1 = courbeN1.take(m).fold(0.0, (a, b) => a + b);
    return n1 <= 0 ? null : (n - n1) / n1 * 100;
  }
}

/// Magasins du portefeuille : réseau d'abord, copie locale si le réseau est indisponible (CDC §3.3).
class MagasinRepository {
  MagasinRepository(this._dio, this._cache);

  final Dio _dio;
  final CacheRepository _cache;

  static const _pageSize = 100;
  static const _maxPages = 20; // garde-fou : 2 000 magasins au plus

  Future<Cached<List<Magasin>>> loadAll(String userId) async {
    try {
      final rows = <dynamic>[];
      for (var page = 1; page <= _maxPages; page++) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/clients',
          queryParameters: {'enrich': 1, 'avecAdresse': 1, 'limit': _pageSize, 'page': page},
        );
        final data = (res.data?['data'] as List?) ?? const [];
        rows.addAll(data);
        final total = (res.data?['total'] as num?)?.toInt() ?? rows.length;
        if (rows.length >= total || data.isEmpty) break;
      }
      await _cache.put(userId, 'magasins', rows);
      return Cached(_parse(rows), DateTime.now());
    } on DioException {
      final cached = await _cache.get(userId, 'magasins');
      if (cached == null) rethrow;
      return Cached(_parse(cached.value as List<dynamic>), cached.fetchedAt, fromCache: true);
    }
  }

  Future<Cached<FicheMagasin>> fiche(String userId, String id, Magasin base) async {
    final key = 'fiche:$id';
    try {
      final res = await _dio.get<Map<String, dynamic>>('/clients/$id');
      await _cache.put(userId, key, res.data);
      return Cached(_parseFiche(res.data!, base), DateTime.now());
    } on DioException {
      final cached = await _cache.get(userId, key);
      if (cached == null) rethrow;
      return Cached(_parseFiche(cached.value as Map<String, dynamic>, base), cached.fetchedAt, fromCache: true);
    }
  }

  /// Historique du magasin ; null si le réseau manque et qu'aucune copie n'existe (la fiche reste utilisable).
  Future<HistoriqueMagasin?> historique(String userId, String id) async {
    final key = 'historique:$id';
    try {
      final res = await _dio.get<Map<String, dynamic>>('/clients/$id/historique');
      await _cache.put(userId, key, res.data);
      return HistoriqueMagasin.fromJson(res.data!);
    } on Object {
      final cached = await _cache.get(userId, key);
      if (cached == null) return null;
      return HistoriqueMagasin.fromJson(Map<String, dynamic>.from(cached.value as Map));
    }
  }

  static List<Magasin> _parse(List<dynamic> rows) => rows.map((e) => Magasin.fromJson(e as Map<String, dynamic>)).toList()
    ..sort((a, b) => a.enseigne.toLowerCase().compareTo(b.enseigne.toLowerCase()));

  static FicheMagasin _parseFiche(Map<String, dynamic> j, Magasin base) {
    final adresse = [j['adresse1'], j['codePostal'], j['ville']]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    return FicheMagasin(
      magasin: base,
      adresse: adresse.isEmpty ? null : adresse,
      telephone: (j['tel1'] as String?)?.trim().isNotEmpty == true ? (j['tel1'] as String).trim() : null,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      periodicite: ((j['periodicites'] as List?)?.firstOrNull as Map?)?['periodicite']?['libelle'] as String?,
      contacts: ((j['contacts'] as List?) ?? const []).map((e) => ContactMagasin.fromJson(e as Map<String, dynamic>)).toList(),
      notes: ((j['notes'] as List?) ?? const []).map((e) => NoteMagasin.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
