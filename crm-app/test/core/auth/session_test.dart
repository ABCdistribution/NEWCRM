import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/auth_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/db/cle_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StockageMemoire implements StockageSecret {
  final Map<String, String> valeurs = {};

  @override
  Future<String?> lire(String nom) async => valeurs[nom];

  @override
  Future<void> ecrire(String nom, String valeur) async => valeurs[nom] = valeur;
}

class _FauxAuth implements AuthApi {
  _FauxAuth(this.reponse);
  final Object reponse; // ReponseConnexion ou ErreurApi

  @override
  Future<ReponseConnexion> connecter(
    String identifiant,
    String motDePasse,
  ) async {
    final r = reponse;
    if (r is ErreurApi) throw r;
    return r as ReponseConnexion;
  }
}

ReponseConnexion _reponse(String role, {String nom = 'Jean DUPONT'}) =>
    ReponseConnexion(
      jeton: 'jeton-secret',
      utilisateur: Utilisateur(
        id: 'u1',
        identifiant: 'jdupont',
        nomAffiche: nom,
        email: 'j@abc.fr',
        roleApi: role,
      ),
    );

ProviderContainer _conteneur(Object reponse, _StockageMemoire stockage) {
  final c = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(_FauxAuth(reponse)),
      stockageSessionProvider.overrideWithValue(StockageSession(stockage)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('rôles et noms', () {
    test("rôle de l'API -> profil mobile", () {
      Role? de(String r) => _reponse(r).utilisateur.role;
      expect(de('COMMERCIAL'), Role.promoteur);
      expect(de('CHEF_SECTEUR'), Role.cs);
      expect(de('DIRECTEUR_REGIONAL'), Role.dir);
      expect(de('DIRECTION'), Role.dir);
      expect(de('ADMIN'), Role.dir);
      expect(de('ADV'), isNull);
      expect(de('MARKETING'), isNull);
    });

    test(
      'prénom et initiales, que l\'AD écrive « Prénom NOM » ou « NOM Prénom »',
      () {
        final a = _reponse('COMMERCIAL', nom: 'Jean DUPONT').utilisateur;
        expect((a.prenom, a.initiales), ('Jean', 'JD'));
        final b = _reponse('COMMERCIAL', nom: 'DUPONT Jean').utilisateur;
        expect((b.prenom, b.initiales), ('Jean', 'DJ'));
        final c = _reponse('COMMERCIAL', nom: 'Madonna').utilisateur;
        expect((c.prenom, c.initiales), ('Madonna', 'M'));
      },
    );
  });

  group('session', () {
    test(
      'connexion réussie : utilisateur, profil et session enregistrée',
      () async {
        final stockage = _StockageMemoire();
        final c = _conteneur(_reponse('CHEF_SECTEUR'), stockage);
        await c.read(sessionProvider.notifier).connecter(' jdupont ', 'mdp');
        expect(c.read(sessionProvider)?.identifiant, 'jdupont');
        expect(c.read(roleProvider), Role.cs);
        final relu = await StockageSession(stockage).lire();
        expect(relu?.nomAffiche, 'Jean DUPONT'); // survit au redémarrage
      },
    );

    test('identifiants refusés : aucune session, aucun profil', () async {
      final stockage = _StockageMemoire();
      final c = _conteneur(
        const ErreurApi(TypeErreurApi.identifiants, statut: 401),
        stockage,
      );
      await expectLater(
        c.read(sessionProvider.notifier).connecter('x', 'y'),
        throwsA(
          isA<ErreurApi>().having(
            (e) => e.message,
            'message',
            'Identifiant ou mot de passe incorrect.',
          ),
        ),
      );
      expect(c.read(sessionProvider), isNull);
      expect(c.read(roleProvider), isNull);
      expect(stockage.valeurs, isEmpty);
    });

    test(
      "rôle sans accès mobile (ADV) : refusé, rien n'est enregistré",
      () async {
        final stockage = _StockageMemoire();
        final c = _conteneur(_reponse('ADV'), stockage);
        await expectLater(
          c.read(sessionProvider.notifier).connecter('adv', 'mdp'),
          throwsA(
            isA<ErreurApi>().having(
              (e) => e.type,
              'type',
              TypeErreurApi.refuse,
            ),
          ),
        );
        expect(c.read(sessionProvider), isNull);
        expect(stockage.valeurs, isEmpty);
      },
    );

    test('déconnexion : session effacée, retour à la connexion', () async {
      final stockage = _StockageMemoire();
      final c = _conteneur(_reponse('COMMERCIAL'), stockage);
      await c.read(sessionProvider.notifier).connecter('jdupont', 'mdp');
      await c.read(sessionProvider.notifier).deconnecter();
      expect(c.read(sessionProvider), isNull);
      expect(c.read(roleProvider), isNull);
      expect(await StockageSession(stockage).lire(), isNull);
    });

    test('session illisible ou de rôle inconnu : ignorée', () async {
      final stockage = _StockageMemoire();
      stockage.valeurs[StockageSession.nomSecret] = 'pas du json';
      expect(await StockageSession(stockage).lire(), isNull);
      await StockageSession(stockage).sauver(_reponse('MARKETING'));
      expect(await StockageSession(stockage).lire(), isNull);
    });
  });
}
