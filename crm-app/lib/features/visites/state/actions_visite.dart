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

  /// « Aucune marque concurrente en rayon » : cocher vide la liste (`conc-aucune`).
  void basculerAucuneMarque() => _maj((v) {
    final aucune = !v.concurrence.aucune;
    return v.copyWith(
      concurrence: Concurrence(
        aucune: aucune,
        liste: aucune ? const [] : v.concurrence.liste,
      ),
    );
  });

  void retirerMarque(int index) => _maj((v) {
    final liste = [...v.concurrence.liste]..removeAt(index);
    return v.copyWith(
      concurrence: Concurrence(aucune: v.concurrence.aucune, liste: liste),
    );
  });

  void ajouterMarque(String marque, double metrage) => _maj(
    (v) => v.copyWith(
      concurrence: Concurrence(
        aucune: v.concurrence.aucune,
        liste: [
          ...v.concurrence.liste,
          MarqueConcurrente(marque: marque, metrage: metrage),
        ],
      ),
    ),
  );

  void basculerBilan() => _maj((v) => v.copyWith(bilanValide: !v.bilanValide));

  void noterBilan(String texte) => _maj((v) => v.copyWith(bilanNote: texte));

  void definirPromos({required bool conformes}) =>
      _maj((v) => v.copyWith(promosConformes: conformes));

  void noterPromos(String texte) => _maj((v) => v.copyWith(promosNote: texte));

  /// Visite PEM réalisée ou non ; réalisée efface la raison (`v-pem`).
  void definirPemRealisee({required bool realisee}) => _maj(
    (v) => v.copyWith(
      pem: VisitePem(realisee: realisee, raison: realisee ? '' : v.pem.raison),
    ),
  );

  void definirRaisonPem(String raison) => _maj(
    (v) => v.copyWith(
      pem: VisitePem(realisee: v.pem.realisee, raison: raison),
    ),
  );

  /// Termine la visite : « À envoyer » et heure de réception (`v-valider-ok`).
  void terminer() => _maj(
    (v) => v.copyWith(etat: EtatVisite.terminee, recu: prochainHorodatage(v)),
  );
}
