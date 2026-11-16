import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/sync/catalogue_provider.dart';
import '../../core/ui/ui.dart';
import 'state/filtres_catalogue_state.dart';
import 'widgets/carte_produit.dart';

/// Onglet « Référentiel produits » (tous les rôles, menu « + »). Maquette : `salesProduits` l.1241-1248.
///
/// Recherche (nom, marque, EAN, code article), bouton scan (message « bientôt disponible »), filtres marque / stock /
/// promotion / mis en avant / kits / PEM dans une feuille, fiche produit en feuille.
class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  /// Le texte cherché vit dans le provider (la maquette le garde dans `S.sProd.q` quand on change d'onglet) :
  /// le champ repart de cette valeur.
  late final TextEditingController _recherche = TextEditingController(
    text: ref.read(filtresCatalogueProvider).q,
  );

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(filtresCatalogueProvider.select((f) => f.q), (_, q) {
      if (_recherche.text != q) _recherche.text = q;
    });
    final filtres = ref.watch(filtresCatalogueProvider);
    final liste = ref.watch(produitsFiltresProvider);
    final store = ref.read(filtresCatalogueProvider.notifier);

    return PageUnivers(
      entete: AppEntete(
        titre: 'Référentiel produits',
        tailleTitre: 21,
        sous: _sousTitre(ref.watch(catalogueProvider), tousProduits().length),
        trailing: RondB(
          '▦',
          semantique: 'Scanner',
          onTap: () => AppToast.show(
            context,
            "Scan du code-barres : bientôt disponible. Saisissez l'EAN dans la recherche.",
          ),
        ),
        extra: BarreRecherche(
          hint: 'Nom, marque, EAN ou code article',
          controller: _recherche,
          onChanged: store.chercher,
          nbFiltres: filtres.nombreActifs,
          onFiltres: () => AppRoutes.filtresCatalogue(context),
        ),
      ),
      enfants: [
        if (liste.isEmpty)
          const Vide('Aucun produit ne correspond.')
        else
          ListePaginee<Produit>(
            elements: liste,
            constructeur: (p) => CarteProduit(
              produit: p,
              onTap: () => AppRoutes.ficheProduit(context, p.id),
            ),
          ),
      ],
    );
  }
}

String _date(DateTime? d) {
  if (d == null) return '';
  const mois = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${mois[d.month - 1]} à $h:$m';
}

/// Sous-titre de l'entête : références et état de la copie locale du catalogue.
String _sousTitre(EtatSynchro etat, int nb) {
  final refs = '$nb références';
  final maj = etat.majLe == null ? '' : ' · mis à jour le ${_date(etat.majLe)}';
  return switch (etat.phase) {
    PhaseSynchro.demo => '$refs · données du 4 nov.',
    PhaseSynchro.chargement =>
      nb == 0 ? 'Téléchargement du catalogue…' : '$refs$maj · synchronisation…',
    PhaseSynchro.ok => '$refs$maj',
    PhaseSynchro.horsLigne =>
      nb == 0
          ? 'Hors connexion : catalogue non téléchargé'
          : '$refs$maj · hors connexion',
    PhaseSynchro.erreur =>
      nb == 0 ? (etat.message ?? 'Catalogue indisponible') : '$refs$maj',
  };
}
