import '../db/app_database.dart';
import '../logic/classes.dart';
import '../models/models.dart';

/// Magasin de l'app à partir d'un client téléchargé du CRM.
///
/// Le CRM ne fournit pas encore CA, évolution, dernière commande ni objectif de visites par client : ces champs
/// restent vides (« — »), rien n'est inventé.
Magasin magasinDepuisClient(ClientLocal c) {
  final ville = _titre(c.ville);
  final adresse = [
    if (c.adresse1 != null) c.adresse1!,
    [
      c.codePostal,
      ville,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' '),
  ].where((s) => s.isNotEmpty).join(', ');
  return Magasin(
    id: c.id,
    nom: ville.isEmpty ? _titre(c.enseigne) : '${_titre(c.enseigne)} – $ville',
    statut: c.actif ? 'Client actif' : 'Client inactif',
    classe: classeValide(c.niveauClass),
    adresse: adresse,
    ca: '—',
    evo: '',
    cde: '—',
    cdeDate: '',
    visites: 0,
    objectif: 0,
    contact: c.contact,
    actif: c.actif,
    reel: true,
  );
}

/// « CARREFOUR MARKET » → « Carrefour Market » (l'import Minos écrit en majuscules).
String _titre(String? s) {
  if (s == null) return '';
  return s
      .toLowerCase()
      .split(RegExp(r'(?<=[\s\-’\x27])'))
      .map((m) => m.isEmpty ? m : m[0].toUpperCase() + m.substring(1))
      .join()
      .trim();
}
