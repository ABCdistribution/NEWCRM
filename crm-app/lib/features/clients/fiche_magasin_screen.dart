import '../../core/data/fiche_client.dart';
import '../../core/sync/fiche_client_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import '../accueil/accueil_logique.dart';
import 'state/commandes_client.dart';
import 'widgets/bloc_objectifs_magasin.dart';
import 'widgets/suivi_magasin.dart';

/// Fiche d'un client (écran empilé `magasin`). Maquette : ficheMag l.1808-1824, objectifs `blocObjMag` l.1800-1804,
/// actions l.1752-1755. Ouverte par `AppRoutes.ficheMagasin(context, magasinId)`.
///
/// Entête (statut, nom, classe et adresse, actions), trois chiffres clés, objectifs et OP du magasin, onglets
/// (promoteur : Aperçu, Contacts, Commandes, Notes ; encadrement : Suivi, Commandes, Contacts, Infos) et barre
/// basse « Ajouter une note » + « Démarrer une visite » (promoteur) ou « Planifier une visite » (encadrement).
class FicheMagasinScreen extends ConsumerStatefulWidget {
  const FicheMagasinScreen({super.key, required this.magasinId});

  final String magasinId;

  @override
  ConsumerState<FicheMagasinScreen> createState() => _FicheMagasinScreenState();
}

class _FicheMagasinScreenState extends ConsumerState<FicheMagasinScreen> {
  /// Onglet choisi ; nul = le premier du rôle (« Aperçu » ou « Suivi »), comme à l'ouverture dans la maquette.
  OngletMagasin? _onglet;

  @override
  Widget build(BuildContext context) {
    final promoteur = ref.watch(roleActifProvider) == Role.promoteur;
    final m = ref.watch(magasinParIdProvider(widget.magasinId));
    if (m == null) {
      return const PageUnivers(
        entete: TopbarEcran(titre: 'Client'),
        enfants: [Vide('Client introuvable.')],
      );
    }
    // Client du CRM : fiche détaillée (contacts, notes, visites, commandes, CA) chargée à l'ouverture.
    final fiche = m.reel ? ref.watch(ficheClientProvider(m.id)).value : null;
    final locales = ref.watch(commandesClientProvider(m.id));
    final commandes = fiche == null
        ? locales
        : [
            ...locales,
            for (final c in fiche.commandes)
              if (!locales.any((l) => l.id == c.id)) c,
          ];
    final onglets = OngletMagasin.pour(promoteur: promoteur);
    final actif = _onglet ?? onglets.first;
    final u = context.univers;

    // Actions externes : inactives (onTap nul) tant que le CRM ne fournit pas la donnée.
    final lanceur = ref.read(lanceurExterneProvider);
    final uriTel =
        uriAppel(fiche?.telephone) ??
        fiche?.contacts.map((c) => uriAppel(c.telephone)).nonNulls.firstOrNull;
    final uriCourriel =
        uriMail(fiche?.mail) ??
        fiche?.contacts.map((c) => uriMail(c.mail)).nonNulls.firstOrNull;
    final uriCarte = uriItineraire(m.adresse);
    VoidCallback? lancer(Uri? uri) =>
        uri == null ? null : () => lancerExterne(context, lanceur, uri);
    final appeler = lancer(uriTel);
    final mail = lancer(uriCourriel);
    final itineraire = lancer(uriCarte);
    void planifier() => AppRoutes.formulaireRdv(
      context,
      cible: CiblePlanning.client,
      ref: m.id,
      depuisFiche: true,
      visite: false,
    );
    void visite() => AppRoutes.demarrerVisite(context, m.id);
    void note() => AppRoutes.noteClient(context, m.id);

    return PageUnivers(
      entete: AppEntete.libre(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const BoutonRetour(), BadgeInfo(m.statut)],
            ),
            const SizedBox(height: 14),
            Text(
              m.nom,
              style: AppText.t(23, w: FontWeight.w800, h: 1.15, c: u.encre),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Classe ${m.classe} · ${m.adresse}',
                style: AppText.t(12.5, c: u.encre2),
              ),
            ),
            if (promoteur)
              RangeeActions(
                actions: [
                  ActionRapide(
                    label: 'Appeler',
                    icone: AppIcons.tel,
                    onTap: appeler,
                  ),
                  ActionRapide(
                    label: 'Mail',
                    icone: AppIcons.mail,
                    onTap: mail,
                  ),
                  ActionRapide(
                    label: 'Itinéraire',
                    icone: AppIcons.nav,
                    onTap: itineraire,
                  ),
                  ActionRapide(label: '＋ Visite', plein: true, onTap: visite),
                ],
              )
            else
              RangeeActions(
                six: true,
                actions: [
                  ActionRapide(
                    label: 'Appeler',
                    icone: AppIcons.tel,
                    onTap: appeler,
                  ),
                  ActionRapide(
                    label: 'Mail',
                    icone: AppIcons.mail,
                    onTap: mail,
                  ),
                  ActionRapide(
                    label: 'Planifier',
                    icone: AppIcons.cal,
                    onTap: planifier,
                  ),
                  ActionRapide(
                    label: 'Visite',
                    icone: AppIcons.pin,
                    onTap: visite,
                  ),
                  ActionRapide(
                    label: 'Commande',
                    icone: AppIcons.doc,
                    onTap: () =>
                        AppRoutes.priseCommande(context, magasinId: m.id),
                  ),
                  ActionRapide(
                    label: 'Itinéraire',
                    icone: AppIcons.nav,
                    onTap: itineraire,
                  ),
                ],
              ),
          ],
        ),
      ),
      enfants: [
        KpiRangee([
          KpiItem(
            'CA 12 mois',
            fiche?.ca12Mois == null ? m.ca : euroCourt(fiche!.ca12Mois!),
            evo: m.evo,
          ),
          KpiItem(
            'Dernière cde',
            m.reel && commandes.isNotEmpty ? commandes.first.ht : m.cde,
            sous: m.reel && commandes.isNotEmpty
                ? commandes.first.date
                : (m.cdeDate.isEmpty ? null : m.cdeDate),
          ),
          if (m.reel)
            KpiItem('Visites / mois', '${fiche?.visitesMois ?? 0}')
          else
            KpiItem(
              'Visites / mois',
              '${m.visites}',
              sous: 'obj. ${m.objectif}',
            ),
        ]),
        // « CA / objectif » et opérations promotionnelles : données de démonstration, jamais pour un vrai client.
        if (!m.reel) BlocObjectifsMagasin(m),
        OngletsPills(
          libelles: [for (final o in onglets) o.libelle],
          index: onglets.indexOf(actif),
          onChanged: (i) => setState(() => _onglet = onglets[i]),
        ),
        switch (actif) {
          OngletMagasin.apercu || OngletMagasin.suivi =>
            m.reel
                ? OngletSuiviReel(
                    fiche: fiche,
                    commandes: commandes,
                    visitePrevue: prochaineVisitePrevue(
                      ref.watch(crmProvider),
                      magasinId: m.id,
                      inclureAujourdhui: true,
                    ),
                  )
                : OngletSuivi(derniereCommande: commandes.firstOrNull),
          OngletMagasin.commandes => OngletCommandes(
            commandes: commandes,
            onCommande: (c) => AppRoutes.detailLivraison(context, c.id),
          ),
          OngletMagasin.contacts => OngletContacts(
            contacts: fiche?.contacts ?? const [],
          ),
          OngletMagasin.notes =>
            m.reel
                ? OngletNotesReel(notes: fiche?.notes ?? const [])
                : const OngletNotes(),
          OngletMagasin.infos => OngletInfos(magasin: m, fiche: fiche),
        },
      ],
      bas: BarreBasse(
        enfants: [
          AppBouton(
            'Ajouter une note',
            variante: VarianteBouton.tonal,
            onPressed: note,
          ),
          AppBouton(
            promoteur ? 'Démarrer une visite' : 'Planifier une visite',
            variante: VarianteBouton.plein,
            onPressed: promoteur ? visite : planifier,
          ),
        ],
      ),
    );
  }
}
