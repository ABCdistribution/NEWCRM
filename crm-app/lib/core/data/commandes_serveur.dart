import '../logic/logic.dart';
import '../models/models.dart';

/// Commandes réelles téléchargées du CRM (nul en démonstration : les commandes de la maquette servent alors).
List<Commande>? _commandesServeur;

void definirCommandesServeur(List<Commande>? commandes) =>
    _commandesServeur = commandes;

List<Commande>? commandesServeur() => _commandesServeur;

String _jourMois(DateTime d) => '${d.day} ${moisCourts[d.month - 1]}';

String _heure(DateTime d) =>
    '${deuxChiffres(d.hour)}:${deuxChiffres(d.minute)}';

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Commande de l'app à partir d'une commande de l'API (`GET /commandes`) ; null si elle est annulée ou sans numéro.
///
/// L'API ne donne pas le nombre de colis : il reste à 0 et l'écran ne l'affiche pas.
Commande? commandeDepuisJson(Map<String, dynamic> j) {
  final numero = _texte(j['numero']);
  if (numero == null || j['annulee'] == true) return null;
  final client = j['client'];
  final clientId = client is Map ? client['id'] : null;
  final dateCmd = _date(j['dateCommande']);
  final expediee = _date(j['dateExpedition']);
  final livraison = _date(j['dateLivraison']);
  final livree = j['statutLivraison'] == 'LIVREE';
  final transporteur = _texte(j['transporteur']);
  final auteur = j['auteur'];
  final total = (j['total'] as num?)?.toDouble() ?? 0;
  return Commande(
    id: numero,
    magasinId: clientId is String ? clientId : '',
    date: dateCmd == null ? '—' : _jourMois(dateCmd),
    ht: euros(total),
    lignes: (j['nbLignes'] as num?)?.toInt() ?? 0,
    statut: livree ? StatutLivraison.livree : StatutLivraison.pasLivree,
    eta: livraison == null
        ? 'à confirmer'
        : (livree ? 'livrée le ${_jourMois(livraison)}' : _jourMois(livraison)),
    colis: 0,
    evenements: [
      if (dateCmd != null)
        EvenementTransport(
          'Commande reçue',
          '${_jourMois(dateCmd)} ${_heure(dateCmd)}',
        ),
      if (expediee != null)
        EvenementTransport(
          'Expédiée',
          '${_jourMois(expediee)}${transporteur == null ? '' : ' · $transporteur'}',
        ),
      if (livree && livraison != null)
        EvenementTransport('Livrée', _jourMois(livraison)),
    ],
    src: j['viaMobile'] == true ? 'Appli' : 'EDI',
    transporteur: transporteur,
    suivi: _texte(j['noSuivi']),
    auteurId: auteur is Map ? _texte(auteur['id']) : null,
    auteurNom: auteur is Map ? _texte(auteur['displayName']) : null,
  );
}
