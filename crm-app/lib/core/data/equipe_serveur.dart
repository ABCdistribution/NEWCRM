import '../logic/logic.dart';
import '../models/models.dart';
import 'equipe_demo.dart';

/// Équipe du périmètre de l'utilisateur, telle que la donne le CRM (`GET /dashboard/carte-equipes`).
class EquipeServeur {
  const EquipeServeur({
    required this.chefs,
    required this.parChef,
    required this.total,
    required this.visites,
    required this.commandes,
  });

  final List<ChefSecteur> chefs;

  /// Promoteurs de chaque chef de secteur, par identifiant du chef.
  final Map<String, List<Promoteur>> parChef;

  /// CA réalisé et objectif du mois sur tout le périmètre.
  final TotalObjectif total;
  final int visites;
  final int commandes;
}

EquipeServeur? _equipe;

/// Remplace (ou, avec null, retire) l'équipe réelle ; appelé par le chargement depuis la base locale.
void definirEquipeServeur(EquipeServeur? equipe) => _equipe = equipe;

EquipeServeur? equipeServeur() => _equipe;

/// Chefs de secteur à afficher : ceux du CRM, sinon ceux de la démonstration (jamais en session réelle : tant que
/// l'équipe n'est pas téléchargée, la liste est vide).
List<ChefSecteur> chefsActuels() =>
    _equipe?.chefs ?? (DemoTemps.reel ? const [] : chefsSecteurDemo);

/// Promoteurs d'un chef de secteur.
List<Promoteur> promoteursDuChef(String id) => _equipe != null
    ? (_equipe!.parChef[id] ?? const [])
    : DemoTemps.reel
    ? const []
    : (promoteursParChef[id] ?? const []);

/// Tous les promoteurs de l'équipe.
List<Promoteur> promoteursTous() => _equipe != null
    ? [for (final l in _equipe!.parChef.values) ...l]
    : DemoTemps.reel
    ? const []
    : tousPromoteurs();

/// Promoteurs de l'équipe de l'utilisateur : ceux du périmètre du CRM, sinon ceux de Nadia H. (démonstration).
List<Promoteur> promoteursDeMonEquipe() => _equipe != null
    ? promoteursTous()
    : DemoTemps.reel
    ? const []
    : (promoteursParChef['n'] ?? const []);

/// Objectif et réalisé du mois de l'équipe : totaux du CRM ; sans équipe téléchargée, zéro en session réelle, sinon
/// ceux des promoteurs de la démonstration (le chef de secteur ne voit que Nadia H.).
TotalObjectif totalEquipe({required bool chefSecteur}) =>
    _equipe?.total ??
    (DemoTemps.reel
        ? const TotalObjectif(0, 0)
        : totalObjectif(
            chefSecteur ? promoteursParChef['n']! : tousPromoteurs(),
          ));

/// Promoteur par nom (démonstration : nom court de la maquette).
Promoteur? promoteurActuelParNom(String nom) {
  for (final p in promoteursTous()) {
    if (p.nom == nom) return p;
  }
  return null;
}

/// Chef de secteur par identifiant.
ChefSecteur? chefActuelParId(String id) {
  for (final c in chefsActuels()) {
    if (c.id == id) return c;
  }
  return null;
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

double _nombre(Object? v) => v is num ? v.toDouble() : 0;

int _entier(Object? v) => v is num ? v.toInt() : 0;

String _initiales(String nom) {
  final mots = nom.split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return '?';
  return mots.take(2).map((m) => m[0].toUpperCase()).join();
}

Promoteur _promoteur(Map<String, dynamic> j) {
  final nom = _texte(j['displayName']) ?? '—';
  return Promoteur(
    nom: nom,
    ini: _initiales(nom),
    mag: _entier(j['nbClients']),
    v: _entier(j['visites']),
    p: 0,
    real: _nombre(j['ca']),
    cible: _nombre(j['objectif']),
    jour: const [],
    reel: true,
    commandes: _entier(j['commandes']),
    userId: j['id'] is String ? j['id'] as String : null,
  );
}

/// Équipe à partir de la réponse de `GET /dashboard/carte-equipes` ; null si la réponse n'a pas la forme attendue.
///
/// Seuls les promoteurs rattachés à un chef de secteur sont repris ; les promoteurs « hors chef » ne sont pas listés.
EquipeServeur? equipeDepuisJson(Map<String, dynamic> j) {
  final regions = j['regions'];
  if (regions is! List) return null;
  final chefs = <ChefSecteur>[];
  final parChef = <String, List<Promoteur>>{};
  var real = 0.0;
  var cible = 0.0;
  var visites = 0;
  var commandes = 0;
  for (final r in regions.whereType<Map<String, dynamic>>()) {
    final stats = r['stats'];
    if (stats is Map<String, dynamic>) {
      real += _nombre(stats['ca']);
      cible += _nombre(stats['objectif']);
      visites += _entier(stats['visites']);
      commandes += _entier(stats['commandes']);
    }
    final regionNom = _texte(r['nom']) ?? '';
    for (final c
        in (r['chefsSecteur'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()) {
      final id = c['id'];
      if (id is! String) continue;
      final nom = _texte(c['displayName']) ?? '—';
      final secteur = c['secteur'];
      chefs.add(
        ChefSecteur(
          id: id,
          nom: nom,
          ini: _initiales(nom),
          region: regionNom,
          secteur: secteur is Map ? (_texte(secteur['nom']) ?? '') : '',
          reel: true,
          visites: _entier(c['visites']),
          commandes: _entier(c['commandes']),
          ca: _nombre(c['ca']),
          objectif: _nombre(c['objectif']),
        ),
      );
      parChef[id] = [
        for (final p
            in (c['promoteurs'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          _promoteur(p),
      ];
    }
  }
  return EquipeServeur(
    chefs: chefs,
    parChef: parChef,
    total: TotalObjectif(real, cible),
    visites: visites,
    commandes: commandes,
  );
}
