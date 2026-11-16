import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/features/equipe/data/equipe_demo.dart';
import 'package:crm_app/features/equipe/data/secteur_demo.dart';
import 'package:crm_app/features/equipe/state/filtres.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les valeurs attendues viennent de la maquette exécutée (`semainesCS`, `donneesSecteur`, `listeSecteur`,
/// `semainesFiltrees` de `maquette/demo-appli.html`) : une chaîne par semaine ou par ligne,
/// champs séparés par « | ».
const Map<String, List<String>> _semainesAttendues = {
  'n': [
    '45|2 – 6 novembre|0|1|5|3|60|ajoute:Auchan – Rouen:visite non prévue;retire:Carrefour Market – Rouen:prévu jeu. 14:00|-|Mar 09:00 Carrefour – Rouen;Mar 11:30 Carrefour – Paris;Mer 10:00 Super U – Versailles;Jeu 14:00 Carrefour Market – Rouen;Ven 09:30 Carrefour – Ivry-sur-Seine',
    '44|26 – 30 octobre|0|0|6|5|83|retire:Monoprix – Caen:prévu Mer 11:00;deplace:Carrefour – Paris:prévu Mar 14:30 → réalisé Mer 15:00;ajoute:Auchan – Rouen:non prévu · Jeu 14:00|lun. 2 nov. à 04:00|Lun 09:30 Carrefour – Rouen;Mar 10:00 Super U – Versailles;Mar 14:30 Carrefour – Paris;Mer 11:00 Monoprix – Caen;Jeu 09:00 E.Leclerc – Paris;Ven 10:00 Carrefour – Ivry-sur-Seine',
    '43|19 – 23 octobre|0|0|14|13|93|ajoute:Auchan – Rouen:visite non prévue|lun. 26 oct. à 04:00|Mar 11:30 Carrefour – Paris;Mer 10:00 Super U – Versailles;Jeu 14:00 Carrefour Market – Rouen;Ven 09:30 Carrefour – Ivry-sur-Seine;Lun 11:00 Auchan – Rouen',
    '42|12 – 16 octobre|0|0|15|15|100||lun. 19 oct. à 04:00|Mar 09:00 Carrefour – Rouen;Mar 11:30 Carrefour – Paris;Mer 10:00 Super U – Versailles;Jeu 14:00 Carrefour Market – Rouen;Ven 09:30 Carrefour – Ivry-sur-Seine',
    '41|5 – 9 octobre|0|0|13|11|85|retire:Carrefour – Versailles:prévu vendredi;retire:Super U – Versailles:prévu vendredi|lun. 12 oct. à 04:00|Mar 11:30 Carrefour – Paris;Mer 10:00 Super U – Versailles;Jeu 14:00 Carrefour Market – Rouen;Ven 09:30 Carrefour – Ivry-sur-Seine;Lun 11:00 Auchan – Rouen',
    '40|28 sept. – 2 octobre|0|0|12|12|100|ajoute:Auchan – Rouen:visite non prévue|lun. 5 oct. à 04:00|Mar 09:00 Carrefour – Rouen;Mar 11:30 Carrefour – Paris;Mer 10:00 Super U – Versailles;Jeu 14:00 Carrefour Market – Rouen;Ven 09:30 Carrefour – Ivry-sur-Seine',
    '39|21 – 25 septembre|1|0|-|9|-||lun. 28 sept. à 04:00|',
  ],
  'k': [
    '45|2 – 6 novembre|0|1|4|3|75||-|Mar 10:00 Super U – Amiens;Mer 14:00 Carrefour – Rouen;Jeu 09:30 Monoprix – Caen;Ven 11:00 Carrefour – Versailles',
    '44|26 – 30 octobre|0|0|12|12|100||lun. 2 nov. à 04:00|Mar 10:00 Super U – Amiens;Mer 14:00 Carrefour – Rouen;Jeu 09:30 Monoprix – Caen;Ven 11:00 Carrefour – Versailles',
    '43|19 – 23 octobre|0|0|14|13|93|ajoute:Auchan – Rouen:visite non prévue|lun. 26 oct. à 04:00|Mer 14:00 Carrefour – Rouen;Jeu 09:30 Monoprix – Caen;Ven 11:00 Carrefour – Versailles;Lun 11:00 Auchan – Rouen',
    '42|12 – 16 octobre|0|0|15|15|100||lun. 19 oct. à 04:00|Mar 10:00 Super U – Amiens;Mer 14:00 Carrefour – Rouen;Jeu 09:30 Monoprix – Caen;Ven 11:00 Carrefour – Versailles',
    '41|5 – 9 octobre|0|0|13|11|85|retire:Carrefour – Versailles:prévu vendredi;retire:Super U – Versailles:prévu vendredi|lun. 12 oct. à 04:00|Mer 14:00 Carrefour – Rouen;Jeu 09:30 Monoprix – Caen;Ven 11:00 Carrefour – Versailles;Lun 11:00 Auchan – Rouen',
    '40|28 sept. – 2 octobre|0|0|12|12|100|ajoute:Auchan – Rouen:visite non prévue|lun. 5 oct. à 04:00|Mar 10:00 Super U – Amiens;Mer 14:00 Carrefour – Rouen;Jeu 09:30 Monoprix – Caen;Ven 11:00 Carrefour – Versailles',
    '39|21 – 25 septembre|1|0|-|9|-||lun. 28 sept. à 04:00|',
  ],
  's': [
    '45|2 – 6 novembre|1|1|-|-|-||-|',
    '44|26 – 30 octobre|1|0|-|9|-||lun. 2 nov. à 04:00|',
    '43|19 – 23 octobre|1|0|14|13|93|ajoute:Auchan – Rouen:visite non prévue|lun. 26 oct. à 04:00|',
    '42|12 – 16 octobre|1|0|15|15|100||lun. 19 oct. à 04:00|',
    '41|5 – 9 octobre|1|0|13|11|85|retire:Carrefour – Versailles:prévu vendredi;retire:Super U – Versailles:prévu vendredi|lun. 12 oct. à 04:00|',
    '40|28 sept. – 2 octobre|1|0|12|12|100|ajoute:Auchan – Rouen:visite non prévue|lun. 5 oct. à 04:00|',
    '39|21 – 25 septembre|1|0|-|9|-||lun. 28 sept. à 04:00|',
  ],
};

const List<String> _visitesAttendues = [
  'Carrefour – Rouen|4 nov. 09:00|Moi|EDI|Envoyée',
  'Carrefour Market – Versailles|4 nov. 09:00|Julien M.|Appli|Envoyée',
  'Carrefour – Rouen|4 nov. 09:00|Léa P.|Appli|Envoyée',
  'E.Leclerc – Paris|4 nov. 09:00|Amine K.|EDI|En cours',
  'Carrefour – Paris|3 nov. 11:00|Moi|Appli|Envoyée',
  'U Express – Boulogne-Billancourt|3 nov. 11:00|Julien M.|EDI|Envoyée',
  'U Express – Paris|3 nov. 11:00|Léa P.|Appli|Envoyée',
  'U Express – Paris|3 nov. 11:00|Amine K.|Appli|Envoyée',
  'Super U – Versailles|3 nov. 10:30|Moi|Appli|Envoyée',
  'Carrefour – Ivry-sur-Seine|3 nov. 10:30|Julien M.|Appli|Envoyée',
  'Carrefour Market – Rouen|3 nov. 10:30|Léa P.|EDI|Envoyée',
  'Carrefour – Versailles|3 nov. 10:30|Amine K.|Appli|Envoyée',
  'Auchan – Rouen|2 nov. 12:30|Moi|EDI|Envoyée',
  'E.Leclerc – Paris|2 nov. 12:30|Julien M.|Appli|Envoyée',
  'Carrefour – Rouen|2 nov. 12:30|Léa P.|Appli|Envoyée',
  'E.Leclerc – Paris|2 nov. 12:30|Amine K.|EDI|Envoyée',
  'Carrefour – Rouen|30 oct. 13:00|Moi|Appli|Envoyée',
  'Carrefour Market – Versailles|30 oct. 13:00|Julien M.|Appli|Envoyée',
  'Carrefour Market – Rouen|30 oct. 13:00|Léa P.|EDI|Envoyée',
  'Carrefour – Versailles|30 oct. 13:00|Amine K.|Appli|Envoyée',
  'Super U – Versailles|29 oct. 14:30|Moi|Appli|Envoyée',
  'Carrefour – Ivry-sur-Seine|29 oct. 14:30|Julien M.|EDI|Envoyée',
  'U Express – Paris|29 oct. 14:30|Léa P.|Appli|Envoyée',
  'U Express – Paris|29 oct. 14:30|Amine K.|Appli|Envoyée',
];

const List<String> _commandesAttendues = [
  'CDE-2041|Super U – Versailles|3 nov.|Moi|EDI|PAS_LIVREE|1 540,00 €',
  'CDE-2039|Carrefour – Paris|3 nov.|Moi|Appli|LIVREE|1 980,00 €',
  'CDE-2048|Carrefour – Ivry-sur-Seine|3 nov.|Julien M.|Appli|PAS_LIVREE|1 540,00 €',
  'CDE-2046|U Express – Boulogne-Billancourt|3 nov.|Julien M.|Appli|LIVREE|1 980,00 €',
  'CDE-2055|Carrefour Market – Rouen|3 nov.|Léa P.|Appli|PAS_LIVREE|1 540,00 €',
  'CDE-2053|U Express – Paris|3 nov.|Léa P.|EDI|LIVREE|1 980,00 €',
  'CDE-2062|Carrefour – Versailles|3 nov.|Amine K.|EDI|PAS_LIVREE|1 540,00 €',
  'CDE-2060|U Express – Paris|3 nov.|Amine K.|Appli|LIVREE|1 980,00 €',
  'CDE-2027|Auchan – Rouen|2 nov.|Moi|Appli|PAS_LIVREE|958,70 €',
  'CDE-2034|E.Leclerc – Paris|2 nov.|Julien M.|EDI|PAS_LIVREE|958,70 €',
  'CDE-2041|Carrefour – Rouen|2 nov.|Léa P.|Appli|PAS_LIVREE|958,70 €',
  'CDE-2048|E.Leclerc – Paris|2 nov.|Amine K.|Appli|PAS_LIVREE|958,70 €',
  'CDE-2032|Carrefour Market – Rouen|30 oct.|Léa P.|Appli|LIVREE|2 340,00 €',
];

String _signatureSemaine(SemaineCs w) => [
  w.n,
  w.periode,
  w.nonRenseignee ? 1 : 0,
  w.enCours ? 1 : 0,
  w.prevues ?? '-',
  w.realisees ?? '-',
  w.pct ?? '-',
  w.ecarts.map((e) => '${e.genre.name}:${e.titre}:${e.point.note}').join(';'),
  w.valide ?? '-',
  w.prevision.map((l) => '${l.jour} ${l.heure} ${l.titre}').join(';'),
].join('|');

String _signatureVisite(ElementSecteur x) {
  final v = x as VisiteSecteur;
  return [
    v.client,
    v.date,
    v.qui,
    v.src,
    v.enCours ? 'En cours' : 'Envoyée',
  ].join('|');
}

String _signatureCommande(ElementSecteur x) {
  final c = x as CommandeSecteur;
  return [c.id, c.client, c.date, c.qui, c.src, c.statut.code, c.ht].join('|');
}

void main() {
  group('semaines des chefs de secteur (semainesCS)', () {
    for (final id in ['n', 'k', 's']) {
      test('chef de secteur « $id » : les sept semaines, champ par champ', () {
        final dart = semainesChefSecteur(id).map(_signatureSemaine).toList();
        expect(dart, _semainesAttendues[id]);
      });
    }

    test('résumé des écarts de chaque semaine de Nadia H. (resumeEcarts)', () {
      final resumes = [
        for (final w in semainesChefSecteur('n'))
          resumeEcarts(w.ecarts.map((e) => e.genre)),
      ];
      expect(resumes, [
        '+1 ajoutée · 1 retirée',
        '+1 ajoutée · 1 retirée · 1 déplacée',
        '+1 ajoutée',
        'aucun écart',
        '2 retirées',
        '+1 ajoutée',
        'aucun écart',
      ]);
    });

    test('Nadia H. : la semaine 44 est comparée ligne à ligne', () {
      final cmp = semainesChefSecteur('n')[1].comparaison!;
      expect(cmp.lignes.map((x) => x.genre), [
        GenreComparaison.fait,
        GenreComparaison.fait,
        GenreComparaison.deplace,
        GenreComparaison.fait,
        GenreComparaison.ajoute,
        GenreComparaison.fait,
      ]);
      expect(cmp.manquees.map((x) => x.reel.titre), ['Monoprix – Caen']);
      expect(cmp.manquees.single.genre, GenreComparaison.retire);
      expect(semainesChefSecteur('k')[1].comparaison, isNull);
    });

    test('le détail des chefs de secteur : prévision, rapport, semaine 44', () {
      expect(detailsChefsSecteur, hasLength(3));
      final n = detailChefSecteur('n');
      expect(n.prev!.at, 'lun. 2 nov. à 08:40');
      expect(n.prev!.lignes, hasLength(5));
      expect(n.rap!.pct, 60);
      expect(n.s44.v, 14);
      final k = detailChefSecteur('k');
      expect(k.prev!.at, 'lun. 2 nov. à 09:15');
      expect(k.prev!.lignes, hasLength(4));
      expect(k.rap!.ecarts, isEmpty);
      final s = detailChefSecteur('s');
      expect(s.prev, isNull);
      expect(s.rap, isNull);
      expect(s.s44.pct, isNull);
      expect(
        s.s44.note,
        'Prévision non renseignée cette semaine-là : pas de comparaison.',
      );
    });

    test('le filtre des semaines (FILTRES_SEM) et ses effectifs', () {
      expect(FiltreSemaines.values.map((f) => f.libelle), [
        'Toutes les semaines',
        'Semaine en cours',
        'Semaines validées',
        'Avec des écarts',
        'Prévision non renseignée',
      ]);
      int nb(String id, FiltreSemaines f) => semainesFiltrees(id, f).length;
      expect(
        [for (final f in FiltreSemaines.values) nb('n', f)],
        [7, 1, 6, 5, 1],
      );
      expect(
        [for (final f in FiltreSemaines.values) nb('k', f)],
        [7, 1, 6, 3, 1],
      );
      expect(
        [for (final f in FiltreSemaines.values) nb('s', f)],
        [7, 1, 6, 3, 7],
      );
    });
  });

  group('visites et commandes du secteur', () {
    test(
      'visites : 24 lignes, les plus récentes d’abord, comme la maquette',
      () {
        final l = listeSecteur(GenreSecteur.visites, const FiltreSecteur());
        expect(l.map(_signatureVisite).toList(), _visitesAttendues);
      },
    );

    test(
      'commandes : 13 lignes, les plus récentes d’abord, comme la maquette',
      () {
        final l = listeSecteur(GenreSecteur.commandes, const FiltreSecteur());
        expect(l.map(_signatureCommande).toList(), _commandesAttendues);
      },
    );

    test('clé de tri des dates (cleDate)', () {
      expect(cleDate('4 nov. 09:00'), 104090);
      expect(cleDate('3 nov.'), 103000);
      expect(cleDate('30 oct. 13:00'), 30130);
      expect(cleDate('29 oct.'), 29000);
    });

    test(
      'filtres : « mes » éléments, un promoteur, un client, une origine',
      () {
        var f = const FiltreSecteur(portee: PorteeSecteur.moi);
        expect(listeSecteur(GenreSecteur.visites, f), hasLength(6));
        expect(listeSecteur(GenreSecteur.commandes, f), hasLength(3));
        f = const FiltreSecteur(promo: 'Léa P.');
        expect(listeSecteur(GenreSecteur.visites, f), hasLength(6));
        expect(listeSecteur(GenreSecteur.commandes, f), hasLength(4));
        f = const FiltreSecteur(client: 'Carrefour – Rouen');
        expect(listeSecteur(GenreSecteur.visites, f), hasLength(4));
        expect(listeSecteur(GenreSecteur.commandes, f), hasLength(1));
        f = const FiltreSecteur(src: SourceCommande.edi);
        final edi = listeSecteur(GenreSecteur.commandes, f);
        expect(edi, hasLength(4));
        expect(edi.every((x) => x.src == 'EDI'), isTrue);
        f = const FiltreSecteur(src: SourceCommande.appli);
        expect(listeSecteur(GenreSecteur.commandes, f), hasLength(9));
        // Le type de commande ne concerne pas les visites.
        expect(listeSecteur(GenreSecteur.visites, f), hasLength(24));
        f = const FiltreSecteur(portee: PorteeSecteur.moi, promo: 'Léa P.');
        expect(listeSecteur(GenreSecteur.visites, f), isEmpty);
      },
    );

    test('clients proposés : sans doublon, par ordre alphabétique', () {
      expect(clientsSecteur(GenreSecteur.visites), [
        'Auchan – Rouen',
        'Carrefour – Ivry-sur-Seine',
        'Carrefour – Paris',
        'Carrefour – Rouen',
        'Carrefour – Versailles',
        'Carrefour Market – Rouen',
        'Carrefour Market – Versailles',
        'E.Leclerc – Paris',
        'Super U – Versailles',
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
      expect(clientsSecteur(GenreSecteur.commandes), [
        'Auchan – Rouen',
        'Carrefour – Ivry-sur-Seine',
        'Carrefour – Paris',
        'Carrefour – Rouen',
        'Carrefour – Versailles',
        'Carrefour Market – Rouen',
        'E.Leclerc – Paris',
        'Super U – Versailles',
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
    });

    test('libellé du sélecteur et pastille des filtres', () {
      const f = FiltreSecteur(
        portee: PorteeSecteur.moi,
        promo: 'Léa P.',
        client: 'Auchan – Rouen',
        src: SourceCommande.appli,
      );
      expect(f.nb, 4);
      expect(
        f.resume(GenreSecteur.commandes),
        'Mes commandes · Léa P. · Auchan – Rouen · Commandes appli',
      );
      expect(const FiltreSecteur().nb, 0);
      expect(
        const FiltreSecteur().resume(GenreSecteur.visites),
        'Visites du secteur',
      );
      expect(
        const FiltreSecteur(
          portee: PorteeSecteur.moi,
        ).resume(GenreSecteur.visites),
        'Mes visites',
      );
      expect(const FiltresEquipe().libelle, 'Chefs de secteur');
      const promos = FiltresEquipe(type: TypeEquipe.promoteurs, region: 'Nord');
      expect(promos.libelle, 'Promoteurs · Nord');
      expect(promos.nb, 2);
      expect(const FiltresEquipe().nb, 0);
    });
  });
}
