/// Visites et commandes du secteur du chef de secteur : maquette `donneesSecteur` (l.910-915), `listeSecteur`
/// (l.916-921) et `cleDate` (l.909). Lecture seule, tirées de l'activité fictive de Nadia H. et de ses promoteurs.
library;

import '../../../core/data/equipe_serveur.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/state/crm_etat.dart';
import '../state/filtres.dart';
import 'equipe_demo.dart';

/// Une ligne de la liste du secteur : une visite ou une commande, avec son auteur et son origine.
sealed class ElementSecteur {
  const ElementSecteur({
    required this.client,
    required this.date,
    required this.qui,
    required this.moi,
    required this.src,
  });

  final String client;

  /// « 4 nov. 09:00 » pour une visite, « 3 nov. » pour une commande.
  final String date;

  /// « Moi » ou le nom court du promoteur.
  final String qui;
  final bool moi;

  /// Origine : « EDI » ou « Appli ».
  final String src;
}

final class VisiteSecteur extends ElementSecteur {
  const VisiteSecteur({
    required super.client,
    required super.date,
    required super.qui,
    required super.moi,
    required super.src,
    required this.enCours,
  });

  final bool enCours;
}

final class CommandeSecteur extends ElementSecteur {
  const CommandeSecteur({
    required super.client,
    required super.date,
    required super.qui,
    required super.moi,
    required super.src,
    required this.id,
    required this.ht,
    required this.statut,
  });

  final String id;

  /// « 1 540,00 € ».
  final String ht;
  final StatutLivraison statut;
}

/// Qui produit l'activité : le chef de secteur (« Moi ») puis chacun de ses promoteurs.
class _Acteur {
  const _Acteur({
    required this.libelle,
    required this.nom,
    required this.visites,
    required this.mag,
    required this.jour,
    this.clients,
    this.moi = false,
  });

  /// « Moi » ou le nom du promoteur.
  final String libelle;

  /// Nom court qui choisit les clients de l'activité (`p.nom` de la maquette).
  final String nom;

  /// Visites réalisées (`p.v`) et nombre de clients (`p.mag`).
  final int visites;
  final int mag;
  final List<VisiteJourPromo> jour;
  final List<String>? clients;
  final bool moi;
}

List<_Acteur> _acteurs() => [
  const _Acteur(
    libelle: 'Moi',
    nom: 'Nadia H.',
    visites: 6,
    mag: 3,
    jour: [],
    clients: clientsChefSecteur,
    moi: true,
  ),
  for (final p in promoteursParChef['n']!)
    _Acteur(libelle: p.nom, nom: p.nom, visites: p.v, mag: p.mag, jour: p.jour),
];

String _idDecale(String id, int decalage) => id.replaceFirstMapped(
  RegExp(r'\d+$'),
  (m) => '${int.parse(m.group(0)!) + decalage}',
);

/// Visites ou commandes du CRM dans le périmètre de l'utilisateur (équipe incluse), à partir du store : les visites
/// des 60 derniers jours et les commandes téléchargées. `moiNom` est le nom de l'utilisateur connecté (ses lignes
/// sont marquées « Moi »).
List<ElementSecteur> donneesSecteurReelles(
  GenreSecteur genre,
  CrmEtat etat,
  String moiNom,
) {
  String nomClient(String id) {
    final m = etat.magasinParId(id);
    return m == null ? '' : nomEtClasse(m.nom, m.classe);
  }

  if (genre == GenreSecteur.visites) {
    return [
      for (final v in [...etat.visites, ...etat.visitesAutresVisibles])
        VisiteSecteur(
          client: nomClient(v.magasinId),
          date: v.date,
          qui: v.par,
          moi: v.par == moiNom,
          src: 'Appli',
          enCours: v.etat == EtatVisite.brouillon,
        ),
    ];
  }
  return [
    for (final c in etat.commandesVisibles)
      CommandeSecteur(
        client: nomClient(c.magasinId),
        date: c.date,
        qui: c.auteurNom ?? '—',
        moi: c.auteurNom != null && c.auteurNom == moiNom,
        src: c.src ?? 'EDI',
        id: c.id,
        ht: c.ht,
        statut: c.statut,
      ),
  ];
}

/// Toutes les visites ou commandes du secteur, avant filtre et tri (`donneesSecteur`). Connecté, `etat` et `moiNom`
/// donnent les lignes du CRM ; sinon ce sont celles de la démonstration.
List<ElementSecteur> donneesSecteur(
  GenreSecteur genre, {
  CrmEtat? etat,
  String moiNom = '',
}) {
  if (equipeServeur() != null || DemoTemps.reel) {
    return etat == null ? const [] : donneesSecteurReelles(genre, etat, moiNom);
  }
  final liste = <ElementSecteur>[];
  final acteurs = _acteurs();
  for (var qi = 0; qi < acteurs.length; qi++) {
    final q = acteurs[qi];
    final a = activitePromoteur(
      nom: q.nom,
      visitesPrevues: q.visites,
      mag: q.mag,
      jour: q.jour,
      clientsPerso: q.clients,
    );
    if (genre == GenreSecteur.visites) {
      for (var xi = 0; xi < a.visites.length; xi++) {
        final v = a.visites[xi];
        liste.add(
          VisiteSecteur(
            client: v.client,
            date: v.date,
            qui: q.libelle,
            moi: q.moi,
            src: (xi + qi) % 3 == 0 ? 'EDI' : 'Appli',
            enCours: v.enCours,
          ),
        );
      }
    } else {
      for (var xi = 0; xi < a.commandes.length; xi++) {
        final c = a.commandes[xi];
        liste.add(
          CommandeSecteur(
            client: c.client,
            date: c.date,
            qui: q.libelle,
            moi: q.moi,
            src: (xi + qi) % 3 == 0 ? 'EDI' : 'Appli',
            id: _idDecale(c.id, qi * 7),
            ht: c.ht,
            statut: c.statut,
          ),
        );
      }
    }
  }
  return liste;
}

/// Clé de tri d'une date « 4 nov. 09:00 » ou « 30 oct. » : plus la date est récente, plus la clé est grande. Le mois
/// compte à partir du mois courant en remontant (novembre avant octobre, décembre avant novembre…), puis le jour,
/// puis l'heure (`cleDate`).
double cleDate(String d) {
  final m = RegExp(r'(\d+) (\S+?)\.?( (\d+):(\d+))?$').firstMatch(d)!;
  final heure = m.group(4) == null
      ? 0.0
      : int.parse(m.group(4)!) * 10 + int.parse(m.group(5)!) / 10;
  final mois = moisCourts.indexWhere(
    (x) => x.replaceAll('.', '') == m.group(2)!.replaceAll('.', ''),
  );
  final courant = DemoTemps.aujourdhui.month - 1;
  final recul = mois < 0 ? 12 : (courant - mois + 12) % 12;
  return (12 - recul) * 100000 + int.parse(m.group(1)!) * 1000 + heure;
}

/// Liste du secteur après filtres, les plus récentes d'abord (`listeSecteur`).
List<ElementSecteur> listeSecteur(
  GenreSecteur genre,
  FiltreSecteur f, {
  CrmEtat? etat,
  String moiNom = '',
}) {
  final l = donneesSecteur(genre, etat: etat, moiNom: moiNom).where((x) {
    if (f.portee == PorteeSecteur.moi && !x.moi) return false;
    if (f.promo != filtreTous && x.qui != f.promo) return false;
    if (f.client != filtreTous && x.client != f.client) return false;
    if (genre == GenreSecteur.commandes &&
        f.src != SourceCommande.toutes &&
        x.src != f.src.code) {
      return false;
    }
    return true;
  });
  return triStable(l, (a, b) => cleDate(b.date).compareTo(cleDate(a.date)));
}

/// Clients proposés dans « Choisir un client » : ceux de la liste du genre, sans doublon, par ordre alphabétique.
List<String> clientsSecteur(
  GenreSecteur genre, {
  CrmEtat? etat,
  String moiNom = '',
}) => triStable({
  for (final x in donneesSecteur(genre, etat: etat, moiNom: moiNom)) x.client,
}, compareFr);
