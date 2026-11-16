import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/material.dart';

/// Page qui rassemble tous les composants : un débordement ou une exception fait échouer le test.
class CatalogueComposants extends StatefulWidget {
  const CatalogueComposants({super.key});

  @override
  State<CatalogueComposants> createState() => _CatalogueComposantsState();
}

class _CatalogueComposantsState extends State<CatalogueComposants> {
  int segment = 0;
  int jour = 2;
  int onglet = 1;
  bool actif = true;
  bool coche = false;
  int qte = 6;
  String q = '';
  int clics = 0;

  @override
  Widget build(BuildContext context) {
    return PageUnivers(
      entete: AppEntete(
        titre: 'Titre de page',
        sous: 'Sous-titre · 12 résultats',
        trailing: RondB('▦', onTap: () => clics++),
        extra: Column(
          children: [
            BarreRecherche(
              hint: 'Rechercher…',
              onChanged: (v) => q = v,
              nbFiltres: 2,
              onFiltres: () => clics++,
              actionsSup: [BoutonFiltre(onTap: () {}, icone: AppIcons.scan)],
            ),
            TuilesRangee([
              const Tuile(libelle: 'RDV du jour', valeur: '2/3'),
              Tuile(
                libelle: 'À contacter',
                valeur: '7',
                centre: true,
                actif: true,
                onTap: () {},
              ),
              const Tuile(
                libelle: 'CA / objectif · du mois',
                flex: 2,
                valeur: '4 200 €',
                complement: '/ 4 900 €',
                tailleValeur: 19,
              ),
            ]),
            SelecteurJours(
              jours: [
                for (var i = 0; i < 5; i++)
                  JourItem(
                    libelle: joursLibelles[i],
                    numero: 2 + i,
                    compte: '$i RDV',
                  ),
              ],
              index: jour,
              onChanged: (i) => setState(() => jour = i),
            ),
          ],
        ),
      ),
      fab: AppFab(label: '＋ Nouveau prospect', onPressed: () => clics++),
      paddingBasFab: true,
      enfants: [
        const TitreLigne(
          'Ma tournée du jour',
          lien: 'Voir tout',
          onLien: _rien,
        ),
        AppCarte(
          prochain: true,
          onTap: () => clics++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLigne(
                children: [
                  const Rond(etat: EtatRond.prochain, child: Text('📍')),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carrefour Market – Versailles',
                          style: AppText.titreCarte,
                        ),
                        Text('11:00 · Client · RDV', style: AppText.sousCarte),
                      ],
                    ),
                  ),
                  const Pastille('Prochain', variante: VariantePastille.violet),
                ],
              ),
              const SizedBox(height: 12),
              AppBouton('Itinéraire', petit: true, onPressed: () {}),
            ],
          ),
        ),
        const AppCarte(
          child: AppLigne(
            alignement: CrossAxisAlignment.center,
            children: [
              Rond(etat: EtatRond.fait, child: Text('✓')),
              Expanded(child: Text('Une étape faite')),
              Pastille('Fait', variante: VariantePastille.vert),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in VariantePastille.values)
              Pastille(v.name, variante: v),
          ],
        ),
        Segment(
          libelles: const ['Mes prospects', 'Tout le secteur'],
          index: segment,
          onChanged: (i) => setState(() => segment = i),
        ),
        OngletsPills(
          libelles: const ['Suivi', 'Commandes', 'Contacts', 'Infos'],
          index: onglet,
          onChanged: (i) => setState(() => onglet = i),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChipChoix('Pas de rayon PEM', selectionne: true, onTap: () {}),
            ChipChoix('Autre', selectionne: false, onTap: () {}),
          ],
        ),
        const KpiRangee([
          KpiItem('CA 12 mois', '29,4 k€', evo: '−14 %'),
          KpiItem('Dernière cde', '958 €', sous: '26 oct.'),
          KpiItem('Visites / mois', '1', sous: 'obj. 2'),
        ]),
        const BandeauInfo(
          titre: 'Rapport en cours',
          icone: '⏳',
          detail: 'Prévision figée le lun. 2 nov.',
        ),
        const BarreProgression(valeur: 0.6),
        const BarreObjectif(real: 4200, cible: 4900),
        const EtapesBarre(
          noms: [
            'Fiche créée',
            'À contacter',
            'RDV pris',
            'En négo',
            'Référencé',
          ],
          segments: 4,
        ),
        const BarreLivraison(
          noms: ['Reçue', 'Expédiée', 'Livrée'],
          etats: [
            EtatSegmentLivraison.rempli,
            EtatSegmentLivraison.rempli,
            EtatSegmentLivraison.vide,
          ],
        ),
        const Timeline([
          TimelineItem(
            icone: '📅',
            titre: 'RDV de négociation prévu',
            date: 'ven. 6 nov.',
            detail: 'Proposition',
          ),
          TimelineItem(
            icone: '＋',
            titre: 'Fiche créée',
            date: '2 oct.',
            detail: 'Source : terrain',
          ),
        ]),
        ChampTexte(
          label: 'Enseigne *',
          hint: 'Ex. Super Proxi',
          erreur: 'Enseigne requise',
          onChanged: (_) {},
        ),
        const ChampTexte(label: 'Remarque', lignes: 3),
        ChampListe<String>(
          label: 'Secteur',
          valeur: 's1',
          options: secteursDemo,
          onChanged: (_) {},
        ),
        OptionRadio(
          label: 'Nom (A → Z)',
          selectionne: true,
          onTap: () {},
          detail: '(12)',
        ),
        OptionRadio(label: 'Classification', selectionne: false, onTap: () {}),
        LigneSwitch(
          label: 'En promotion',
          valeur: actif,
          onChanged: (v) => setState(() => actif = v),
        ),
        Row(
          children: [
            CaseCoche(
              cochee: coche,
              onChanged: (v) => setState(() => coche = v),
            ),
          ],
        ),
        StepperQte(
          valeur: qte,
          onMoins: () => setState(() => qte--),
          onPlus: () => setState(() => qte++),
        ),
        const TitreFiltre('Marque'),
        const SectionTitre('Identité'),
        const LigneCle('Adresse', '104 avenue des Champs, 78000 Versailles'),
        const LigneEcart(
          titre: 'Auchan – Rouen',
          detail: 'Ajouté (non prévu) · Jeu 14:00',
          symbole: '＋',
          premiere: true,
        ),
        const MessageErreur('Indiquez le client ou le lieu.'),
        const EncadreImportant(
          titre: '⚠ Important',
          texte: 'Cette consigne est transmise à l’ADV.',
        ),
        EncadreConsigne(
          titre: '⏳ Ne pas livrer avant le 16 nov.',
          texte: 'Motif : Inventaire',
          lien: 'Modifier',
          onLien: () {},
        ),
        const Astuce('Le produit sera disponible à partir du 12 nov.'),
        const Chiffres([Chiffre('14', 'visites'), Chiffre('93 %', 'du prévu')]),
        const Pied('Lecture seule.', centre: true),
        const EnAttente(),
        const Vide('Aucun client.'),
        const Row(
          children: [
            BadgeEtat('En cours', couleur: AppColors.ok),
            SizedBox(width: 8),
            BadgeInfo('Client actif'),
          ],
        ),
        const Row(
          children: [
            NumeroEtape(1, etat: EtatNumero.faite),
            NumeroEtape(2, etat: EtatNumero.courante),
            NumeroEtape(3, etat: EtatNumero.aFaire),
          ],
        ),
        const Row(
          children: [
            BadgeRole(Role.cs),
            SizedBox(width: 8),
            BadgeRole(Role.dir),
          ],
        ),
        const Selecteur('Tous les chefs de secteur', onTap: _rien),
        const SizedBox(height: 12),
        RangeeActions(
          actions: [
            ActionRapide(label: 'Appeler', icone: AppIcons.tel, onTap: () {}),
            ActionRapide(label: 'Mail', icone: AppIcons.mail, onTap: () {}),
            ActionRapide(label: 'Planifier', icone: AppIcons.cal, onTap: () {}),
            ActionRapide(label: 'Visite', icone: AppIcons.pin, onTap: () {}),
            ActionRapide(label: 'Commande', icone: AppIcons.doc, onTap: () {}),
            ActionRapide(
              label: 'Itinéraire',
              icone: AppIcons.nav,
              onTap: () {},
            ),
          ],
          six: true,
        ),
        RangeeActions(
          actions: [
            ActionRapide(label: 'Appeler', icone: AppIcons.tel, onTap: () {}),
            ActionRapide(label: 'Mail', icone: AppIcons.mail, onTap: () {}),
            ActionRapide(
              label: 'Itinéraire',
              icone: AppIcons.nav,
              onTap: () {},
            ),
            ActionRapide(label: '＋ Visite', onTap: () {}, plein: true),
          ],
        ),
        Rangee(
          margeHaut: 12,
          children: [
            AppBouton('Annuler', onPressed: () {}),
            const AppBouton(
              'Désactivé',
              onPressed: null,
              variante: VarianteBouton.tonal,
            ),
            AppBouton(
              'Supprimer',
              onPressed: () {},
              variante: VarianteBouton.danger,
            ),
          ],
        ),
        AppBouton('Valider', onPressed: () {}, variante: VarianteBouton.plein),
        AppBouton(
          'Clair',
          onPressed: () {},
          variante: VarianteBouton.clair,
          pleineLargeur: false,
        ),
      ],
      bas: BarreBasse(
        enfants: [
          AppBouton(
            'Changer d’étape',
            variante: VarianteBouton.tonal,
            onPressed: () {},
          ),
          AppBouton(
            'Passer en client',
            variante: VarianteBouton.plein,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

const joursLibelles = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

void _rien() {}
