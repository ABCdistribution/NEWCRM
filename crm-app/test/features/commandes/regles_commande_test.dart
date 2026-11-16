import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/commandes/logic/liste_commandes.dart';
import 'package:crm_app/features/commandes/logic/regles_commande.dart';
import 'package:crm_app/features/commandes/state/commande_en_cours.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:crm_app/features/commandes/state/filtres_commandes.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

Produit _p(String id) => produitParId(id)!;

List<String> _ids(List<Produit> l) => [for (final p in l) p.id];

void main() {
  group('Stock affiché (stockInfo l.1588)', () {
    test('trois niveaux, texte et couleur', () {
      expect(infoStock(_p('a13')).texte, 'Rupture · disponible le 12 nov.');
      expect(infoStock(_p('a13')).couleur, const Color(0xFFDC2626));
      expect(infoStock(_p('a2')).texte, 'Stock bas · 45 disponibles');
      expect(infoStock(_p('a2')).couleur, const Color(0xFFB45309));
      expect(infoStock(_p('a1')).texte, 'En stock · 98 disponibles');
      expect(infoStock(_p('a1')).couleur, const Color(0xFF059669));
    });
  });

  group('Produits de remplacement (remplacements l.1590-1593)', () {
    test(
      'la même famille d’abord, puis le prix le plus proche, trois au plus',
      () {
        // a4 : Colorations à 14,61 € → a3 (même famille), puis a2 (8,01 d'écart) avant a1 (11,15).
        expect(_ids(produitsDeRemplacement(_p('a4'))), ['a3', 'a2', 'a1']);
        // a13 : aucune autre « Protections SPF » ; le prix décide (20,05 €).
        expect(_ids(produitsDeRemplacement(_p('a13'))), ['a14', 'a9', 'a11']);
        expect(_ids(produitsDeRemplacement(_p('a1'))), ['a2', 'a3', 'a4']);
        expect(_ids(produitsDeRemplacement(_p('a5'))), ['a8', 'a6', 'a7']);
      },
    );

    test(
      'jamais le produit lui-même, jamais un produit en rupture, toujours la même marque',
      () {
        for (final p in produitsCatalogue) {
          final r = produitsDeRemplacement(p);
          expect(r.length, lessThanOrEqualTo(3));
          for (final x in r) {
            expect(x.id, isNot(p.id));
            expect(x.stock, isNot(NiveauStock.rupture));
            expect(x.cat, p.cat);
          }
        }
      },
    );
  });

  group('Quantité reprise (besoin l.1645)', () {
    test('le manque de stock, sinon le colisage', () {
      const a4 = 'a4'; // 8 disponibles, colisage 6
      expect(quantiteReprise(_p(a4), const LigneCommande(a4, 9)), 1);
      expect(quantiteReprise(_p(a4), const LigneCommande(a4, 20)), 12);
      expect(quantiteReprise(_p(a4), const LigneCommande(a4, 6)), 6);
      expect(quantiteReprise(_p(a4), null), 6);
      expect(quantiteReprise(_p('a13'), null), 6);
    });
  });

  group('Catalogue proposé (cmdEcran l.1604-1605)', () {
    test('recherche sur le nom, la marque, la référence et l’EAN', () {
      expect(produitsProposes(q: ''), hasLength(14));
      expect(_ids(produitsProposes(q: 'ROUGE')), ['a9', 'a10', 'a14']);
      expect(produitsProposes(q: 'franck'), hasLength(4));
      expect(_ids(produitsProposes(q: '900040')), ['a13']);
      expect(_ids(produitsProposes(q: '376123450016')), ['a1']);
      expect(produitsProposes(q: 'zzz'), isEmpty);
    });

    test('marque et masquage des ruptures', () {
      expect(produitsProposes(q: '', cat: 'MB Milano'), hasLength(6));
      expect(
        produitsProposes(q: '', cat: 'MB Milano', masquer: true),
        hasLength(5),
      );
      expect(produitsProposes(q: '', masquer: true), hasLength(13));
      expect(nbProduitsFiltres(), 14);
      expect(nbProduitsFiltres(cat: 'Jean Louis David'), 4);
      expect(nbProduitsFiltres(cat: 'MB Milano', masquer: true), 5);
    });
  });

  group('Formats', () {
    test('date du champ, motif final, libellé d’articles', () {
      expect(dateJourMoisAnnee('2026-11-16'), '16/11/2026');
      expect(motifFinal('Impératif', ''), 'Impératif');
      expect(motifFinal('Autre', ' Travaux '), 'Travaux');
      expect(motifFinal('Autre', '  '), 'Autre');
      expect(libelleArticles(0), '0 article');
      expect(libelleArticles(1), '1 article');
      expect(libelleArticles(12), '12 articles');
    });
  });

  group('Commande en cours (S.cmd)', () {
    test('démarrer, ajouter au colisage, retirer jusqu’à zéro', () {
      final c = conteneurPour(Role.promoteur);
      final n = c.read(commandeEnCoursProvider.notifier);
      expect(c.read(commandeEnCoursProvider), isNull);
      n.ajouter('a1'); // sans commande : sans effet
      expect(c.read(commandeEnCoursProvider), isNull);

      n.demarrer(magasinId: 'm1', visiteId: 'd0');
      var cmd = c.read(commandeEnCoursProvider)!;
      expect(cmd.magasinId, 'm1');
      expect(cmd.depuisVisite, 'd0');
      expect(cmd.lignes, isEmpty);
      expect(cmd.deAttente, isNull);

      n.ajouter('a5'); // colisage de 12
      n.ajouter('a5');
      cmd = c.read(commandeEnCoursProvider)!;
      expect(cmd.ligne('a5')!.qty, 13);
      expect(cmd.nbArticles, 13);
      expect(cmd.total, closeTo(13 * 20.81, 1e-9));

      for (var i = 0; i < 13; i++) {
        n.retirer('a5');
      }
      expect(c.read(commandeEnCoursProvider)!.lignes, isEmpty);
      n.retirer('a5'); // déjà absent : sans effet
      expect(c.read(commandeEnCoursProvider)!.lignes, isEmpty);
    });

    test(
      'remplacement : on garde le disponible, le reste passe au produit choisi',
      () {
        final c = conteneurPour(Role.promoteur);
        final n = c.read(commandeEnCoursProvider.notifier)
          ..demarrer(magasinId: 'm1');
        for (var i = 0; i < 9; i++) {
          n.ajouter('a4'); // 6 puis 7, 8, 9...
        }
        expect(c.read(commandeEnCoursProvider)!.ligne('a4')!.qty, 14);
        n.choisirRemplacement('a4', 'a3');
        var cmd = c.read(commandeEnCoursProvider)!;
        expect(cmd.ligne('a4')!.qty, 8);
        expect(cmd.ligne('a3')!.qty, 6); // 14 − 8
        expect(cmd.ligne('a3')!.remplace, 'a4');

        // Un produit déjà dans le panier reçoit la quantité en plus et garde son origine.
        n.ajouter('a4'); // 9
        n.choisirRemplacement('a4', 'a3');
        cmd = c.read(commandeEnCoursProvider)!;
        expect(cmd.ligne('a4')!.qty, 8);
        expect(cmd.ligne('a3')!.qty, 7);
        expect(cmd.ligne('a3')!.remplace, 'a4');
      },
    );

    test(
      'remplacement d’un produit absent du panier : une ligne au colisage',
      () {
        final c = conteneurPour(Role.promoteur);
        final n = c.read(commandeEnCoursProvider.notifier)
          ..demarrer(magasinId: 'm1')
          ..choisirRemplacement('a13', 'a14');
        final cmd = c.read(commandeEnCoursProvider)!;
        expect(cmd.lignes, hasLength(1));
        expect(cmd.ligne('a14')!.qty, 6);
        expect(cmd.ligne('a14')!.remplace, 'a13');
        expect(cmd.nbFiltres, 0);
        n.terminer();
        expect(c.read(commandeEnCoursProvider), isNull);
      },
    );

    test('filtres du catalogue et compteur', () {
      final c = conteneurPour(Role.promoteur);
      final n = c.read(commandeEnCoursProvider.notifier)
        ..demarrer(magasinId: 'm1');
      n.choisirMarque('MB Milano');
      expect(c.read(commandeEnCoursProvider)!.cat, 'MB Milano');
      expect(c.read(commandeEnCoursProvider)!.nbFiltres, 1);
      n.basculerMasquer();
      expect(c.read(commandeEnCoursProvider)!.nbFiltres, 2);
      n.majRecherche('rouge');
      expect(c.read(commandeEnCoursProvider)!.q, 'rouge');
      n.reinitialiserFiltres();
      final cmd = c.read(commandeEnCoursProvider)!;
      expect(cmd.cat, isNull);
      expect(cmd.masquer, isFalse);
      expect(cmd.nbFiltres, 0);
      expect(cmd.q, 'rouge'); // la recherche n'est pas un filtre
      n.choisirMarque(null);
      expect(c.read(commandeEnCoursProvider)!.cat, isNull);
    });

    test(
      'consigne : activation, annulation incomplète, conservation si complète',
      () {
        final c = conteneurPour(Role.promoteur);
        final n = c.read(commandeEnCoursProvider.notifier)
          ..demarrer(magasinId: 'm1');
        expect(n.basculerConsigne(), isTrue); // activée : la feuille s'ouvre
        n.choisirMotif('Impératif');
        n.annulerConsigne(); // incomplète : abandonnée
        var cmd = c.read(commandeEnCoursProvider)!;
        expect(cmd.pas, isFalse);
        expect(cmd.motifPas, isEmpty);

        n.basculerConsigne();
        n.choisirMotif('Inventaire');
        n.majDateMin('2026-11-16');
        expect(c.read(commandeEnCoursProvider)!.consigneComplete, isTrue);
        n.choisirMotif('Impératif'); // modification puis annulation : conservée
        n.annulerConsigne();
        cmd = c.read(commandeEnCoursProvider)!;
        expect(cmd.pas, isTrue);
        expect(cmd.motifPas, 'Impératif');
        expect(cmd.dateMin, '2026-11-16');

        expect(n.basculerConsigne(), isFalse); // décochée : tout est effacé
        cmd = c.read(commandeEnCoursProvider)!;
        expect(cmd.pas, isFalse);
        expect(cmd.dateMin, isEmpty);
        expect(cmd.motifPas, isEmpty);
      },
    );

    test('un changement de profil abandonne la commande en cours', () {
      final c = conteneurPour(Role.promoteur);
      c.read(commandeEnCoursProvider.notifier).demarrer(magasinId: 'm1');
      expect(c.read(commandeEnCoursProvider), isNotNull);
      c.read(roleProvider.notifier).choisir(Role.dir);
      expect(c.read(commandeEnCoursProvider), isNull);
    });
  });

  group('Liste des commandes (commandesListe l.1198-1203)', () {
    CrmEtat etat(Role r) => CrmEtat.initial(r);

    test('périmètre, portée et tri stable selon le rôle', () {
      final promo = commandesListe(
        etat(Role.promoteur),
        const FiltresCommandes(portee: PorteeCommandes.mes),
      );
      expect(
        [for (final c in promo) c.id],
        ['CDE-2039', 'CDE-2027', 'CDE-2018', 'CDE-1984', 'CDE-1930'],
      );
      final cs = commandesListe(
        etat(Role.cs),
        const FiltresCommandes(portee: PorteeCommandes.toutes),
      );
      expect(cs, hasLength(6));
      // « Mes commandes » du chef de secteur : aucune ne porte son nom.
      expect(
        commandesListe(
          etat(Role.cs),
          const FiltresCommandes(portee: PorteeCommandes.mes),
        ),
        isEmpty,
      );
      expect(
        commandesListe(
          etat(Role.dir),
          const FiltresCommandes(portee: PorteeCommandes.toutes),
        ),
        hasLength(10),
      );
    });

    test('filtres d’état, de type et de période, compteurs sans l’état', () {
      final e = etat(Role.dir);
      const base = FiltresCommandes(portee: PorteeCommandes.toutes);
      expect(
        commandesListe(e, base.copyWith(etat: EtatCommande.pasLivree)),
        hasLength(5),
      );
      expect(
        commandesListe(e, base.copyWith(etat: EtatCommande.livree)),
        hasLength(5),
      );
      // Ignorer l'état : tout revient, les autres filtres restent.
      expect(
        commandesListe(
          e,
          base.copyWith(etat: EtatCommande.livree, type: TypeCommande.edi),
          ignorerEtat: true,
        ),
        hasLength(7), // les 7 commandes EDI, livrées ou non
      );
      expect(
        commandesListe(e, base.copyWith(type: TypeCommande.appli)),
        hasLength(3), // CDE-2041, CDE-2033 et CDE-1984 : pas EDI
      );
      expect(
        commandesListe(e, base.copyWith(periode: PeriodeCommandes.jour)),
        isEmpty,
      );
      // 7 derniers jours : 28 oct. (7 jours) et plus récent.
      expect(
        [
          for (final c in commandesListe(
            e,
            base.copyWith(periode: PeriodeCommandes.semaine),
          ))
            c.id,
        ],
        ['CDE-2041', 'CDE-2039', 'CDE-2033', 'CDE-2036', 'CDE-2030'],
      );
    });

    test(
      'la recherche porte sur le client, le numéro et l’auteur, sans tenir compte de la casse',
      () {
        final e = etat(Role.dir);
        const base = FiltresCommandes(portee: PorteeCommandes.toutes);
        expect(commandesListe(e, base.copyWith(q: 'cde-2041')), hasLength(1));
        expect(commandesListe(e, base.copyWith(q: 'ROUEN')), hasLength(2));
        expect(commandesListe(e, base.copyWith(q: 'amine')), hasLength(1));
        expect(commandesListe(e, base.copyWith(q: 'léa')), hasLength(2));
        expect(commandesListe(e, base.copyWith(q: 'inconnu')), isEmpty);
      },
    );

    test('compteur de filtres et portée par défaut', () {
      expect(porteeParDefaut(Role.promoteur), PorteeCommandes.mes);
      expect(porteeParDefaut(Role.cs), PorteeCommandes.toutes);
      expect(porteeParDefaut(Role.dir), PorteeCommandes.toutes);
      const f = FiltresCommandes(portee: PorteeCommandes.mes);
      expect(f.nbActifs(Role.promoteur), 0);
      expect(
        f.nbActifs(Role.dir),
        1,
      ); // « Mes commandes » s'écarte du défaut de l'encadrement
      expect(
        f
            .copyWith(
              etat: EtatCommande.livree,
              periode: PeriodeCommandes.jour,
              type: TypeCommande.edi,
            )
            .nbActifs(Role.promoteur),
        3,
      );
      expect(porteeTexte(Role.promoteur), 'sur vos clients');
      expect(porteeTexte(Role.cs), 'de votre secteur');
      expect(porteeTexte(Role.dir), 'de votre région');
    });

    test('« Réinitialiser » garde la recherche', () {
      final c = conteneurPour(Role.promoteur);
      final n = c.read(filtresCommandesProvider.notifier);
      n.maj(
        (f) => f.copyWith(
          q: 'cde',
          etat: EtatCommande.livree,
          portee: PorteeCommandes.toutes,
        ),
      );
      n.reinitialiser();
      final f = c.read(filtresCommandesProvider);
      expect(f.q, 'cde');
      expect(f.etat, EtatCommande.tous);
      expect(f.portee, PorteeCommandes.mes);
    });
  });
}
