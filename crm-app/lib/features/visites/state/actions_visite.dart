import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../logic/visites_logique.dart';

/// Modifications d'une visite en cours de saisie : chacune a le même effet que l'action de la maquette du même nom.
/// Elles passent toutes par le store partagé, que les autres écrans lisent.
class ActionsVisite {
  const ActionsVisite(this._store, this.visiteId);

  final CrmNotifier _store;
  final String visiteId;

  void _maj(Visite Function(Visite v) f) => _store.majVisite(visiteId, f);

  Map<EtapeDph, String> _horodater(Visite v, EtapeDph e) =>
      v.etapeFaite(e) ? v.chrono : {...v.chrono, e: prochainHorodatage(v)};

  /// Une photo de plus à une étape photo ; la première horodate l'étape (`v-etape`).
  void ajouterPhoto(EtapeDph e) => _maj(
    (v) => v.copyWith(
      photos: {...v.photos, e: (v.photos[e] ?? 0) + 1},
      chrono: _horodater(v, e),
    ),
  );

  /// Une photo de moins à une étape photo (la photo supprimée de l'appareil).
  void retirerPhoto(EtapeDph e) => _maj((v) {
    final n = (v.photos[e] ?? 0) - 1;
    return v.copyWith(photos: {...v.photos, e: n < 0 ? 0 : n});
  });

  /// Horodate l'étape si elle ne l'est pas encore (`v-etape-ok`).
  void enregistrerEtape(EtapeDph e) =>
      _maj((v) => v.copyWith(chrono: _horodater(v, e)));

  /// Coche ou décoche un kit du rayon ; un kit décoché perd sa distribution numérique (`kit-toggle`).
  void basculerKit(String code) => _maj((v) {
    if (v.kits.contains(code)) return _sansKit(v, code);
    return v.copyWith(kits: [...v.kits, code], dn: {...v.dn, code: 0});
  });

  /// Retire un kit de la vérification DN (`kit-retire`).
  void retirerKit(String code) => _maj((v) => _sansKit(v, code));

  /// Décoche tous les kits (`kit-vider`).
  void viderKits() => _maj((v) => v.copyWith(kits: const [], dn: const {}));

  Visite _sansKit(Visite v, String code) => v.copyWith(
    kits: v.kits.where((k) => k != code).toList(),
    dn: {
      for (final e in v.dn.entries)
        if (e.key != code) e.key: e.value,
    },
  );

  /// Réponse à « une commande à mettre en rayon ? ».
  void definirCommandeEnRayon({required bool oui}) =>
      _maj((v) => v.copyWith(commandeEnRayon: oui));

  /// Choisit la raison d'absence de commande (identifiant CRM et libellé).
  void choisirRaisonAbsence(String id, String libelle) =>
      _maj((v) => v.copyWith(raisonAbsenceId: id, raisonAbsence: libelle));

  /// Une commande prise efface la raison d'absence (les deux s'excluent).
  void effacerRaisonAbsence() => _maj(
    (v) => Visite(
      id: v.id,
      num: v.num,
      magasinId: v.magasinId,
      par: v.par,
      parId: v.parId,
      etat: v.etat,
      date: v.date,
      age: v.age,
      chrono: v.chrono,
      photos: v.photos,
      recu: v.recu,
      dn: v.dn,
      kits: v.kits,
      commandeEnRayon: v.commandeEnRayon,
      reponses: v.reponses,
      indispensables: v.indispensables,
      libellesIndispensables: v.libellesIndispensables,
      cmd: v.cmd,
      typeVisite: v.typeVisite,
      propositionPemId: v.propositionPemId,
      articlesPem: v.articlesPem,
      libellesArticlesPem: v.libellesArticlesPem,
    ),
  );

  /// Réponse à une question du questionnaire ; une valeur vide retire la réponse.
  void repondre(String questionId, String valeur) => _maj((v) {
    final r = {...v.reponses};
    if (valeur.isEmpty) {
      r.remove(questionId);
    } else {
      r[questionId] = valeur;
    }
    return v.copyWith(reponses: r);
  });

  /// Relève un produit indispensable : présent ou absent.
  void releverIndispensable(String articleId, {required bool present}) => _maj(
    (v) =>
        v.copyWith(indispensables: {...v.indispensables, articleId: present}),
  );

  /// Relève d'un coup tous les produits donnés comme présents.
  void toutPresent(Iterable<String> articleIds) => _maj(
    (v) => v.copyWith(
      indispensables: {
        ...v.indispensables,
        for (final id in articleIds) id: true,
      },
    ),
  );

  /// Relève un article PEM : présent ou absent. Un article absent n'est jamais « mis en avant » ; un article présent
  /// garde son choix (non mis en avant au premier relevé).
  void releverArticlePem(String articleId, {required bool present}) => _maj(
    (v) => v.copyWith(
      articlesPem: {
        ...v.articlesPem,
        articleId: (
          present: present,
          misEnAvant:
              present && (v.articlesPem[articleId]?.misEnAvant ?? false),
        ),
      },
    ),
  );

  /// Un article PEM présent est mis en avant ou non ; sans effet tant que sa présence n'est pas relevée.
  void mettreEnAvantArticlePem(String articleId, {required bool misEnAvant}) =>
      _maj((v) {
        final releve = v.articlesPem[articleId];
        if (releve == null || !releve.present) return v;
        return v.copyWith(
          articlesPem: {
            ...v.articlesPem,
            articleId: (present: true, misEnAvant: misEnAvant),
          },
        );
      });

  /// Termine la visite : « À envoyer » et heure de réception (`v-valider-ok`).
  void terminer() => _maj(
    (v) => v.copyWith(etat: EtatVisite.terminee, recu: prochainHorodatage(v)),
  );
}
